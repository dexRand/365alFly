#!/usr/bin/env bash
# pptx-deploy — gestisce l'ambiente Windows + PowerPoint reale (dockur/windows)
# per pptx-open: init della config, doctor dell'host, generazione della config
# Office, avvio/stop della VM e accesso via web-VNC/RDP.
#
# Questo script è la sola porta d'ingresso: non invocare `docker compose` a
# mano, così .env e provisioning OEM restano coerenti.
set -Eeuo pipefail

SCRIPT_NAME="${0##*/}"
readonly SCRIPT_NAME
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
DEPLOY_DIR="${PPTX_DEPLOY_DIR:-$ROOT_DIR/deploy}"
readonly DEPLOY_DIR
ENV_FILE="${PPTX_ENV_FILE:-$DEPLOY_DIR/.env}"
readonly ENV_FILE
ENV_EXAMPLE="$DEPLOY_DIR/.env.example"
readonly ENV_EXAMPLE
COMPOSE_FILE="${PPTX_COMPOSE_FILE:-$DEPLOY_DIR/compose.yaml}"
readonly COMPOSE_FILE
OEM_DIR="$DEPLOY_DIR/oem"
readonly OEM_DIR
OFFICE_DIR="$OEM_DIR/office"
readonly OFFICE_DIR
FONTS_SRC="${PPTX_FONTS_SRC:-$ROOT_DIR/winapps-baseline/fonts}"
readonly FONTS_SRC
FONTS_DST="$OEM_DIR/fonts"
readonly FONTS_DST

DEFAULT_ODT_URL="https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_20326-20112.exe"
readonly DEFAULT_ODT_URL

# docker può essere sostituito nei test (PPTX_DOCKER_BIN=docker finto).
DOCKER_BIN="${PPTX_DOCKER_BIN:-docker}"

log()  { printf '%s\n' "$*" >&2; }
warn() { printf 'attenzione: %s\n' "$*" >&2; }
die()  { printf 'errore: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Uso: $SCRIPT_NAME <comando> [opzioni]

Ambiente Windows + Microsoft PowerPoint reale (dockur/windows) per pptx-open.

Comandi:
  init [--force]   Crea deploy/.env dal template con una password casuale.
  doctor           Verifica i prerequisiti host (KVM, docker, disco, RAM).
  office-config    Genera deploy/oem/office/configuration.xml da .env.
  prepare          Prepara la cartella OEM (config Office + font).
  up               doctor + prepare + avvia la VM in background.
  down             Ferma la VM (i dati restano nel volume).
  reset [--yes]    Ferma la VM ed elimina il volume (perde tutto).
  logs             Segue i log del container.
  status           Stato del container.
  url              Stampa gli indirizzi di accesso (VNC web / RDP).
  help             Questo messaggio.

Flussi tipici:
  $SCRIPT_NAME init && $SCRIPT_NAME up
  $SCRIPT_NAME url            # apri l'URL nel browser e usa PowerPoint
  $SCRIPT_NAME reset --yes    # ambiente disposable: ricrea da zero

Config: $ENV_FILE (da $ENV_EXAMPLE)
EOF
}

# --- .env -------------------------------------------------------------------

# shellcheck disable=SC1091  # path dinamico (ROOT_DIR); la lib è testata a parte
source "$ROOT_DIR/scripts/lib/pptx-common.sh"

# Carica .env (parser sicuro in pptx-common.sh) o esce con messaggio chiaro.
load_env() {
  pptx_load_env "$ENV_FILE" || die ".env non trovato ($ENV_FILE); esegui: $SCRIPT_NAME init"
}

# Legge una variabile da .env senza eseguirlo (per messaggi e URL).
env_file_get() { pptx_env_get "$1" "$ENV_FILE"; }

gen_password() {
  head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-24
}

cmd_init() {
  local force=0 arg
  for arg in "$@"; do
    case "$arg" in
      --force|-f) force=1 ;;
      *) die "init: opzione non riconosciuta: $arg" ;;
    esac
  done
  if [ -e "$ENV_FILE" ] && [ "$force" -ne 1 ]; then
    die ".env esiste già ($ENV_FILE); usa --force per sovrascrivere"
  fi
  [ -f "$ENV_EXAMPLE" ] || die "template mancante: $ENV_EXAMPLE"

  local password
  password="$(gen_password)"
  sed "s|^VM_PASSWORD=.*|VM_PASSWORD=${password}|" "$ENV_EXAMPLE" > "$ENV_FILE"
  chmod 600 "$ENV_FILE"

  log "creato $ENV_FILE (chmod 600)"
  log "utente VM: $(env_file_get VM_USER) — password generata in .env"
  log "prossimo passo: $SCRIPT_NAME up"
}

# --- doctor -----------------------------------------------------------------

cmd_doctor() {
  local failures=0

  echo "=== pptx-open / doctor — $(date '+%F %T') ==="

  if [ -e /dev/kvm ]; then
    echo "  [OK]   KVM: /dev/kvm presente"
  else
    echo "  [FAIL] KVM: /dev/kvm mancante (servono VT-x/AMD-V o nested virt)"
    failures=$((failures + 1))
  fi

  if command -v "$DOCKER_BIN" >/dev/null 2>&1; then
    echo "  [OK]   docker: $(command -v "$DOCKER_BIN")"
    if "$DOCKER_BIN" compose version >/dev/null 2>&1; then
      echo "  [OK]   docker compose: plugin disponibile"
    elif command -v docker-compose >/dev/null 2>&1; then
      echo "  [OK]   docker compose: docker-compose v2 ($(command -v docker-compose))"
    else
      echo "  [FAIL] docker compose: né plugin né docker-compose"
      failures=$((failures + 1))
    fi
  else
    echo "  [FAIL] docker: non trovato (installa docker + docker-compose)"
    failures=$((failures + 1))
  fi

  local min_free_gb="${PPTX_MIN_FREE_GB:-40}"
  local free_gb
  free_gb="$(df -Pk "$DEPLOY_DIR" | awk 'NR==2 {printf "%d", $4/1024/1024}')"
  if [ "${free_gb:-0}" -ge "$min_free_gb" ]; then
    echo "  [OK]   disco: ${free_gb} GiB liberi (>= ${min_free_gb})"
  else
    echo "  [FAIL] disco: ${free_gb} GiB liberi (servono >= ${min_free_gb})"
    failures=$((failures + 1))
  fi

  local min_ram_gb="${PPTX_MIN_RAM_GB:-8}"
  local mem_gb
  mem_gb="$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)"
  if [ "${mem_gb:-0}" -ge "$min_ram_gb" ]; then
    echo "  [OK]   RAM: ${mem_gb} GiB totali (>= ${min_ram_gb})"
  else
    echo "  [FAIL] RAM: ${mem_gb} GiB totali (servono >= ${min_ram_gb})"
    failures=$((failures + 1))
  fi

  if [ "$failures" -eq 0 ]; then
    echo "  Esito: host pronto."
  else
    echo "  Esito: $failures requisito/i mancante/i."
  fi

  # BTRFS + disco raw: CoW può danneggiare il setup Windows. Mitigazione una
  # volta sola: chattr +C sulla directory del volume (No_COW per i nuovi file).
  # Non la verifichiamo (la dir del volume è root-only): solo promemoria.
  local docker_root fs_type
  docker_root="$("$DOCKER_BIN" info --format '{{.DockerRootDir}}' 2>/dev/null)" || docker_root=""
  [ -n "$docker_root" ] || docker_root="/var/lib/docker"
  fs_type="$(stat -f -c %T "$docker_root" 2>/dev/null || echo unknown)"
  if [ "$fs_type" = "btrfs" ]; then
    echo "  [info] /storage è su btrfs: se non l'hai già fatto, una volta sola:"
    echo "         sudo chattr +C \"\$(${DOCKER_BIN} volume inspect -f '{{.Mountpoint}}' pptx-open_vmdata)\""
  fi

  return "$failures"
}

# --- Office config ----------------------------------------------------------

# auto -> volume (attivabile con key) se c'è una key, altrimenti M365 (trial).
resolve_office_edition() {
  local edition="$1" key="$2"
  case "$edition" in
    auto) if [ -n "$key" ]; then echo "ltsc2024"; else echo "o365"; fi ;;
    *) echo "$edition" ;;
  esac
}

normalize_office_key() {
  local raw
  raw="$(printf '%s' "$1" | tr -d '[:space:]-' | tr '[:lower:]' '[:upper:]')"
  printf '%s' "$raw" | sed -E 's/(.{5})/\1-/g; s/-$//'
}

validate_office_key() {
  case "$1" in
    [A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]) return 0 ;;
    *) return 1 ;;
  esac
}

cmd_office_config() {
  load_env

  local edition raw_key key=""
  edition="$(resolve_office_edition "${OFFICE_EDITION:-auto}" "${OFFICE_KEY:-}")"
  raw_key="${OFFICE_KEY:-}"

  local product channel activate=0
  case "$edition" in
    ltsc2024) product="ProPlus2024Volume"; channel="PerpetualVL2024"; activate=1 ;;
    ltsc2021) product="ProPlus2021Volume"; channel="PerpetualVL2021"; activate=1 ;;
    2019)     product="ProPlus2019Volume";   channel="PerpetualVL2019"; activate=1 ;;
    o365)     product="O365ProPlusRetail";   channel="Current";         activate=0 ;;
    *) die "OFFICE_EDITION non valido: '$edition' (auto|ltsc2024|ltsc2021|2019|o365)" ;;
  esac

  local pidkey_attr=""
  if [ -n "$raw_key" ]; then
    key="$(normalize_office_key "$raw_key")"
    validate_office_key "$key" || die "OFFICE_KEY non valida (attesa xxxxx-xxxxx-xxxxx-xxxxx-xxxxx)"
    pidkey_attr=" PIDKEY=\"$key\""
  elif [ "$edition" != "o365" ]; then
    warn "edizione $edition senza OFFICE_KEY: Office sarà installato ma non attivato (sola lettura)"
  fi

  local language="${OFFICE_LANGUAGE:-en-us}"
  local language_line
  language_line="$(printf '      <Language ID="%s" />' "$language")"

  local exclude_lines="" app
  local -a apps=()
  IFS=',' read -r -a apps <<< "${OFFICE_EXCLUDE:-}"
  for app in "${apps[@]}"; do
    app="${app// /}"
    [ -n "$app" ] || continue
    exclude_lines+="$(printf '      <ExcludeApp ID="%s" />' "$app")"$'\n'
  done

  local activate_line=""
  [ "$activate" -eq 1 ] && activate_line='  <Property Name="AUTOACTIVATE" Value="1" />'

  mkdir -p "$OFFICE_DIR"
  local config_xml="$OFFICE_DIR/configuration.xml"
  cat > "$config_xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<Configuration ID="pptx-open">
  <Add OfficeClientEdition="64" Channel="$channel">
    <Product ID="$product"$pidkey_attr>
$language_line
$exclude_lines    </Product>
  </Add>
  <RemoveMSI />
  <Display Level="None" AcceptEULA="TRUE" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
$activate_line
  <Logging Level="Standard" Path="C:\OEM\office\ODT.log" />
  <Updates Enabled="FALSE" />
</Configuration>
EOF
  chmod 600 "$config_xml"
  printf '%s\n' "${ODT_URL:-$DEFAULT_ODT_URL}" > "$OFFICE_DIR/odt-url.txt"

  local key_state="none"
  [ -n "$key" ] && key_state="set"
  log "scritto $config_xml (edition=$edition product=$product channel=$channel key=$key_state)"
}

# --- prepare ----------------------------------------------------------------

cmd_prepare() {
  load_env

  if [ "${INSTALL_OFFICE:-Y}" = "N" ]; then
    log "INSTALL_OFFICE=N: Office non verrà installato"
    rm -f "$OFFICE_DIR/configuration.xml" "$OFFICE_DIR/odt-url.txt"
  else
    cmd_office_config
  fi

  if compgen -G "$FONTS_SRC/*.ttf" >/dev/null; then
    mkdir -p "$FONTS_DST"
    cp -f "$FONTS_SRC"/*.ttf "$FONTS_DST"/
    log "font copiati in $FONTS_DST"
  else
    warn "nessun font in $FONTS_SRC (il gate di fedeltà sui font ne avrà bisogno)"
  fi

  # Cartella condivisa bidirezionale (Z:\ nella VM). Vi si seminano i deck di
  # test per il gate di fedeltà, senza sporcare il repo.
  local shared_dir="${SHARED_DIR:-./shared}"
  case "$shared_dir" in
    /*) ;;
    *) shared_dir="$DEPLOY_DIR/$shared_dir" ;;
  esac
  mkdir -p "$shared_dir"
  local seed_src="${PPTX_SEED_SRC:-$ROOT_DIR/winapps-baseline/test_files}"
  local seed_dst
  seed_dst="$(cd "$shared_dir" && pwd)/test_files"
  if [ "$seed_dst" != "$seed_src" ] && compgen -G "$seed_src/*.pptx" >/dev/null; then
    mkdir -p "$seed_dst"
    cp -u "$seed_src"/*.pptx "$seed_dst"/
    log "cartella condivisa: $shared_dir (deck di test in test_files/, visibili in Z:\\)"
  else
    log "cartella condivisa: $shared_dir (visibile in Z:\\)"
  fi
}

# --- compose ----------------------------------------------------------------

compose_run() {
  [ -f "$ENV_FILE" ] || die ".env non trovato ($ENV_FILE); esegui: $SCRIPT_NAME init"
  if command -v "$DOCKER_BIN" >/dev/null 2>&1 && "$DOCKER_BIN" compose version >/dev/null 2>&1; then
    "$DOCKER_BIN" compose --env-file "$ENV_FILE" --file "$COMPOSE_FILE" "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose --env-file "$ENV_FILE" --file "$COMPOSE_FILE" "$@"
  else
    die "serve 'docker compose' (plugin) o 'docker-compose'"
  fi
}

cmd_up() {
  cmd_doctor || die "prerequisiti host non soddisfatti (vedi sopra)"
  cmd_prepare
  log "avvio VM: al primo avvio scarica Windows e installa Office (30-60 min)."
  compose_run up -d
  cmd_url
  log "segui lo stato con: $SCRIPT_NAME status   (log: $SCRIPT_NAME logs)"
}

cmd_down() {
  compose_run down
  log "VM fermata; i dati restano nel volume."
}

cmd_reset() {
  local assume_yes=0 arg
  for arg in "$@"; do
    case "$arg" in
      --yes|-y) assume_yes=1 ;;
      *) die "reset: opzione non riconosciuta: $arg" ;;
    esac
  done
  if [ "$assume_yes" -ne 1 ]; then
    die "reset elimina Windows e Office installati; conferma con: $SCRIPT_NAME reset --yes"
  fi
  compose_run down --volumes --remove-orphans
  log "ambiente eliminato (volume rimosso)."
}

cmd_logs() {
  compose_run logs --follow --tail 200
}

cmd_status() {
  compose_run ps
}

cmd_url() {
  local addr web rdp vnc
  addr="$(env_file_get BIND_ADDR)"; addr="${addr:-127.0.0.1}"
  web="$(env_file_get WEB_PORT)"; web="${web:-8006}"
  rdp="$(env_file_get RDP_PORT)"; rdp="${rdp:-3389}"
  vnc="$(env_file_get VNC_PORT)"; vnc="${vnc:-5900}"
  cat <<EOF
  VNC web : http://${addr}:${web}/     (utente/password in deploy/.env)
  VNC     : ${addr}:${vnc}
  RDP     : ${addr}:${rdp}
EOF
}

# --- dispatch ---------------------------------------------------------------

main() {
  local command="${1:-help}"
  [ "$#" -gt 0 ] && shift

  case "$command" in
    init)          cmd_init "$@" ;;
    doctor)        cmd_doctor "$@" ;;
    office-config) cmd_office_config "$@" ;;
    prepare)       cmd_prepare "$@" ;;
    up)            cmd_up "$@" ;;
    down)          cmd_down "$@" ;;
    reset)         cmd_reset "$@" ;;
    logs)          cmd_logs "$@" ;;
    status)        cmd_status "$@" ;;
    url)           cmd_url "$@" ;;
    help|-h|--help) usage ;;
    *) die "comando sconosciuto: '$command' (usa: $SCRIPT_NAME help)" ;;
  esac
}

main "$@"
