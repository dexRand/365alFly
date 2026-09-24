#!/usr/bin/env bash
# setup — prepara l'host Linux per pptx-open.
#
# Controlla cosa manca (docker, docker compose, FreeRDP, KVM) e installa solo
# i pacchetti assenti, con il package manager della distro. Idempotente: se è
# già tutto presente non tocca nulla.
#
# Uso:
#   scripts/setup.sh              # verifica e installa ciò che manca
#   scripts/setup.sh --check      # non installa: riporta solo lo stato (exit 1 se manca qualcosa)
#   scripts/setup.sh --dry-run    # mostra cosa installerebbe, senza eseguire
#   scripts/setup.sh --with-dev   # aggiunge shellcheck + bats (sviluppo/test)
#
# Exit code: 0 ok · 1 prerequisiti mancanti (--check) / errore · 2 uso errato.
set -Eeuo pipefail

SCRIPT_NAME="${0##*/}"
readonly SCRIPT_NAME

# Override per test/ambienti particolari.
DOCKER_BIN="${PPTX_DOCKER_BIN:-docker}"
FREERDP_BIN="${PPTX_FREERDP_BIN:-xfreerdp3}"
KVM_DEV="${PPTX_KVM_DEV:-/dev/kvm}"

MODE="install"   # install | check | dry-run
WITH_DEV=0
ASSUME_YES=0

log()  { printf '%s\n' "$*" >&2; }
warn() { printf 'attenzione: %s\n' "$*" >&2; }
die()  { printf 'errore: %s\n' "$*" >&2; exit 1; }
ok()   { printf '  [OK]   %s\n' "$*"; }
miss() { printf '  [MISS] %s\n' "$*"; }
plan() { printf '  [PLAN] %s\n' "$*"; }

usage() {
  cat <<EOF
Uso: $SCRIPT_NAME [opzioni]

Prepara l'host Linux per pptx-open: installa solo i pacchetti mancanti
(docker, docker compose, FreeRDP), abilita docker, aggiunge l'utente al
gruppo docker e verifica KVM.

Opzioni:
  --check       verifica senza installare (exit 1 se manca qualcosa)
  --dry-run     mostra le azioni previste, senza eseguirle
  --with-dev    installa anche shellcheck e bats (sviluppo/test)
  --yes, -y     non chiedere conferma
  -h, --help    questo messaggio

Variabili:
  PPTX_DOCKER_BIN              binario docker (default: docker)
  PPTX_FREERDP_BIN             client FreeRDP (default: xfreerdp3)
  PPTX_KVM_DEV                 device KVM da verificare (default: /dev/kvm)
  PPTX_SETUP_OS_ID            forza l'ID distro (es. arch, debian, fedora)
  PPTX_SETUP_OS_LIKE          forza ID_LIKE
  PPTX_SETUP_FREERDP_FALLBACKS client FreeRDP alternativi (default: xfreerdp wlfreerdp3)

Dopo il setup:
  scripts/pptx-deploy.sh init && scripts/pptx-deploy.sh up
EOF
}

# --- rilevamento host -------------------------------------------------------

have_cmd() { command -v "$1" >/dev/null 2>&1; }

find_freerdp() {
  local first="$FREERDP_BIN" c fallbacks
  if have_cmd "$first"; then printf '%s' "$first"; return 0; fi
  if [ "${PPTX_SETUP_FREERDP_FALLBACKS+set}" = "set" ]; then
    fallbacks="$PPTX_SETUP_FREERDP_FALLBACKS"
  else
    fallbacks="xfreerdp3 xfreerdp wlfreerdp3"
  fi
  for c in $fallbacks; do
    if have_cmd "$c"; then printf '%s' "$c"; return 0; fi
  done
  return 1
}

have_compose() {
  if have_cmd "$DOCKER_BIN" && "$DOCKER_BIN" compose version >/dev/null 2>&1; then
    return 0
  fi
  have_cmd docker-compose
}

in_docker_group() {
  id -nG "${USER:-$(id -un)}" 2>/dev/null | tr ' ' '\n' | grep -qx docker
}

detect_os() {
  OS_ID="${PPTX_SETUP_OS_ID:-}"
  OS_LIKE="${PPTX_SETUP_OS_LIKE:-}"
  if [ -z "$OS_ID" ] && [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091  # file di sistema, non del repo
    . /etc/os-release
    OS_ID="${ID:-}"
    OS_LIKE="${ID_LIKE:-}"
  fi
  OS_ID="${OS_ID:-unknown}"
  OS_LIKE="${OS_LIKE:-}"
}

os_family() {
  local id="$1" like="$2"
  case " $id $like " in
    *" arch "*) echo "arch"; return 0 ;;
    *" debian "*|*" ubuntu "*) echo "debian"; return 0 ;;
    *" fedora "*|*" rhel "*|*" centos "*) echo "fedora"; return 0 ;;
  esac
  return 1
}

# Imposta PM, family_label e le variabili pkg_* per la famiglia rilevata.
set_packages() {
  case "$1" in
    arch)
      PM="pacman"; family_label="Arch"
      pkg_docker="docker"; pkg_compose="docker-compose"; pkg_freerdp="freerdp"
      ;;
    debian)
      PM="apt-get"; family_label="Debian/Ubuntu"
      pkg_docker="docker.io"; pkg_compose="docker-compose-v2"; pkg_freerdp="freerdp3-x11"
      ;;
    fedora)
      PM="dnf"; family_label="Fedora/RHEL"
      pkg_docker="docker"; pkg_compose="docker-compose"; pkg_freerdp="freerdp"
      ;;
    *) die "distribuzione non supportata (ID='${OS_ID}'): installa a mano docker, docker compose e FreeRDP. Vedi docs/deploy.md" ;;
  esac
  pkg_shellcheck="shellcheck"
  pkg_bats="bats"
}

# --- verifica ---------------------------------------------------------------

check_all() {
  local failures=0 fr
  echo "=== pptx-open / setup — $(date '+%F %T') ==="

  if have_cmd "$DOCKER_BIN"; then
    ok "docker: $(command -v "$DOCKER_BIN")"
  else
    miss "docker: non trovato"
    failures=$((failures + 1))
  fi

  if have_compose; then
    ok "docker compose: disponibile"
  else
    miss "docker compose: né plugin né docker-compose"
    failures=$((failures + 1))
  fi

  if fr="$(find_freerdp)"; then
    ok "FreeRDP: $fr ($(command -v "$fr"))"
  else
    miss "FreeRDP: non trovato (serve xfreerdp3)"
    failures=$((failures + 1))
  fi

  if [ -e "$KVM_DEV" ]; then
    ok "KVM: $KVM_DEV presente"
  else
    miss "KVM: $KVM_DEV mancante (servono VT-x/AMD-V o virtualizzazione annidata)"
    failures=$((failures + 1))
  fi

  if in_docker_group; then
    ok "gruppo docker: utente presente"
  else
    warn "gruppo docker: utente non presente (docker funziona comunque via sudo)"
  fi

  if [ "$failures" -eq 0 ]; then
    echo "  Esito: host pronto."
  else
    echo "  Esito: $failures requisito/i mancante/i."
  fi
  return "$failures"
}

# Elenca i pacchetti mancanti secondo le capability, in base ai pkg_* correnti.
missing_packages() {
  local -a out=()
  have_cmd "$DOCKER_BIN" || out+=("$pkg_docker")
  have_compose || out+=("$pkg_compose")
  find_freerdp >/dev/null || out+=("$pkg_freerdp")
  if [ "$WITH_DEV" -eq 1 ]; then
    have_cmd shellcheck || out+=("$pkg_shellcheck")
    have_cmd bats || out+=("$pkg_bats")
  fi
  printf '%s\n' "${out[@]+"${out[@]}"}"
}

full_packages() {
  local -a out=("$pkg_docker" "$pkg_compose" "$pkg_freerdp")
  if [ "$WITH_DEV" -eq 1 ]; then
    out+=("$pkg_shellcheck" "$pkg_bats")
  fi
  printf '%s\n' "${out[@]}"
}

# --- esecuzione -------------------------------------------------------------

install_cmd_string() {
  local s=""
  [ "$(id -u)" -ne 0 ] && s="sudo "
  case "$PM" in
    pacman)  printf '%s' "${s}pacman -S --needed --noconfirm $*" ;;
    apt-get) printf '%s' "${s}apt-get update && ${s}apt-get install -y $*" ;;
    dnf)     printf '%s' "${s}dnf install -y $*" ;;
  esac
}

run_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

install_packages() {
  case "$PM" in
    pacman)  run_root pacman -S --needed --noconfirm "$@" ;;
    apt-get) run_root apt-get update && run_root apt-get install -y "$@" ;;
    dnf)     run_root dnf install -y "$@" ;;
  esac
}

ensure_docker_service() {
  if command -v systemctl >/dev/null 2>&1; then
    if run_root systemctl enable --now docker >/dev/null 2>&1; then
      ok "servizio docker: abilitato e avviato"
    else
      warn "non sono riuscito ad abilitare/avviare docker: fallo a mano (systemctl enable --now docker)"
    fi
  fi
}

ensure_docker_group() {
  RELOGIN=0
  if in_docker_group; then
    ok "gruppo docker: utente già presente"
    return 0
  fi
  if run_root usermod -aG docker "${USER:-$(id -un)}" >/dev/null 2>&1; then
    ok "utente aggiunto al gruppo docker"
    RELOGIN=1
  else
    warn "non sono riuscito ad aggiungere l'utente al gruppo docker"
  fi
}

next_steps() {
  log ""
  log "Prossimi passi:"
  log "  scripts/pptx-deploy.sh init     # crea deploy/.env (password casuale)"
  log "  scripts/pptx-deploy.sh up       # primo avvio ~30-60 min (Windows + Office)"
  log "  wrapper/pptx-open file.pptx     # apri il file con PowerPoint reale"
  if [ "${RELOGIN:-0}" -eq 1 ]; then
    warn "sei stato aggiunto al gruppo docker: fai logout/login (o \`newgrp docker\`) prima di usare docker senza sudo."
  fi
}

# --- main -------------------------------------------------------------------

main() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --check)    MODE="check" ;;
      --dry-run)  MODE="dry-run" ;;
      --with-dev) WITH_DEV=1 ;;
      --yes|-y)   ASSUME_YES=1 ;;
      -h|--help)  usage; exit 0 ;;
      *)
        printf 'opzione sconosciuta: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  # In --check non serve conoscere il package manager.
  if [ "$MODE" = "check" ]; then
    check_all
    return $?
  fi

  detect_os
  if ! family="$(os_family "$OS_ID" "$OS_LIKE")"; then
    die "distribuzione non supportata (ID='$OS_ID'): installa a mano docker, docker compose e FreeRDP. Vedi docs/deploy.md"
  fi
  set_packages "$family"

  # missing_packages restituisce una riga vuota quando non c'è nulla da fare.
  local -a missing=()
  while IFS= read -r line; do
    [ -n "$line" ] && missing+=("$line")
  done < <(missing_packages)

  if [ "$MODE" = "dry-run" ]; then
    local -a full=()
    while IFS= read -r line; do [ -n "$line" ] && full+=("$line"); done < <(full_packages)
    echo "Distro              : $family_label (ID='$OS_ID')"
    echo "Gestore pacchetti   : $PM"
    echo "Pacchetti ($family_label) : ${full[*]}"
    if [ "${#missing[@]}" -gt 0 ]; then
      echo "Da installare        : ${missing[*]}"
      echo "Comando              : $(install_cmd_string "${missing[@]}")"
    else
      echo "Da installare        : nessuno (host già pronto)"
    fi
    return 0
  fi

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "=== pptx-open / setup — $(date '+%F %T') ==="
    echo "  Distro: $family_label — da installare: ${missing[*]}"
    plan "$(install_cmd_string "${missing[@]}")"
    if [ "$ASSUME_YES" -ne 1 ] && [ -t 0 ]; then
      printf 'Procedo con l installazione? [y/N] ' >&2
      read -r answer
      case "$answer" in y|Y|yes|YES|s|S|si|SI) ;; *) die "annullato" ;; esac
    fi
    install_packages "${missing[@]}"
  else
    log "Nessun pacchetto da installare."
  fi

  ensure_docker_service
  ensure_docker_group

  check_all || warn "alcuni requisiti restano mancanti: vedi sopra"
  next_steps
}

main "$@"
