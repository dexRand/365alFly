#!/usr/bin/env bash
# Funzioni condivise da scripts/pptx-deploy.sh e wrapper/pptx-open:
# lettura SICURA di deploy/.env (niente source/eval: un valore con spazi non
# può diventare un comando).
#
# Uso: source "$ROOT_DIR/scripts/lib/pptx-common.sh"
#      pptx_load_env "$ENV_FILE"
#      path="$(pptx_env_get SHARED_DIR "$ENV_FILE")"

if [ -n "${PPTX_COMMON_SOURCED:-}" ]; then return 0; fi
PPTX_COMMON_SOURCED=1

# Chiavi lette da .env (docker compose legge il file per conto suo).
PPTX_ENV_KEYS="VM_USER VM_PASSWORD WINDOWS_VERSION WINDOWS_KEY OFFICE_EDITION OFFICE_KEY OFFICE_LANGUAGE OFFICE_EXCLUDE INSTALL_OFFICE ODT_URL SHARED_DIR BIND_ADDR WEB_PORT RDP_PORT VNC_PORT"
readonly PPTX_ENV_KEYS

# Legge una variabile da .env senza eseguirlo.
pptx_env_get() {
  local key="$1" file="${2:-${PPTX_ENV_FILE:-}}"
  [ -f "$file" ] || return 1
  sed -n "s/^${key}=//p" "$file" | tail -n 1
}

# Carica .env esportando le chiavi in PPTX_ENV_KEYS. Ritorna 1 se il file manca.
pptx_load_env() {
  local file="${1:-${PPTX_ENV_FILE:-}}"
  [ -f "$file" ] || return 1

  local line key value
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    case "$line" in *=*) ;; *) continue ;; esac

    key="${line%%=*}"
    value="${line#*=}"
    case " $PPTX_ENV_KEYS " in
      *" $key "*) ;;
      *) continue ;;
    esac

    # Rimuove un eventuale paio di quote (singole o doppie).
    case "$value" in
      \"*\") value="${value#\"}"; value="${value%\"}" ;;
      \'*\') value="${value#\'}"; value="${value%\'}" ;;
    esac

    printf -v "$key" '%s' "$value"
    export "${key:?}"
  done < "$file"
}

# Risolve SHARED_DIR rispetto a DEPLOY_DIR (come fa docker compose) e la crea.
pptx_resolve_shared_dir() {
  local deploy_dir="$1" shared_dir="${2:-./shared}"
  case "$shared_dir" in
    /*) printf '%s\n' "$shared_dir" ;;
    *) printf '%s\n' "$deploy_dir/$shared_dir" ;;
  esac
}
