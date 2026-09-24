#!/usr/bin/env bash
# Test "explode" end-to-end (Task 10 / Fase 3 del piano strategico).
#
# Sequenza: apri -> modifica -> salva -> chiudi -> file aggiornato sull'host.
#
# Esercita la pipeline reale del wrapper in modalità `--vnc` (stage nel volume
# condiviso -> trigger via monitor QEMU -> attesa `done.txt` -> riscrittura del
# file host). Poiché l'agente è headless, la modifica manuale dell'utente è
# sostituita da un helper in-VM che usa PowerPoint REALE via COM per aprire il
# file, cambiare una shape, salvare e chiudere (vedi scripts/e2e/).
#
# Uso: scripts/e2e-explode.sh
# Env: PPTX_E2E_SRC   deck di partenza (default textboxes.pptx)
#      PPTX_E2E_KEEP=1 conserva i file di lavoro a fine test
set -Eeuo pipefail

SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SELF_DIR/.." && pwd)"

# shellcheck disable=SC1091  # path dinamico (ROOT_DIR); la lib è testata a parte
source "$ROOT_DIR/scripts/lib/pptx-common.sh"

DEPLOY_DIR="${PPTX_DEPLOY_DIR:-$ROOT_DIR/deploy}"
ENV_FILE="${PPTX_ENV_FILE:-$DEPLOY_DIR/.env}"
SRC="${PPTX_E2E_SRC:-$ROOT_DIR/winapps-baseline/test_files/textboxes.pptx}"
WRAPPER="$ROOT_DIR/wrapper/pptx-open"
MARKER="E2E-OK-365alFly"

log() { printf '%s\n' "$*" >&2; }
die() { printf 'errore: %s\n' "$*" >&2; exit 1; }

[ -f "$SRC" ] || die "deck di partenza non trovato: $SRC"
[ -f "$ENV_FILE" ] || die ".env non trovato: $ENV_FILE"
pptx_load_env "$ENV_FILE" || die "impossibile leggere $ENV_FILE"
SHARE="$(pptx_resolve_shared_dir "$DEPLOY_DIR" "${SHARED_DIR:-./shared}")"
[ -d "$SHARE" ] || die "cartella condivisa non trovata: $SHARE"

WORK="$SHARE/e2e"
# La sorgente non deve stare dentro WORK: viene rimossa all'inizio del test.
case "$SRC" in
  "$WORK"/*) die "PPTX_E2E_SRC non può stare dentro $WORK (viene ripulita); usa una copia altrove" ;;
esac
rm -rf "$WORK"
mkdir -p "$WORK"
DECK="$WORK/deck.pptx"
cp -f "$SRC" "$DECK"
before="$(sha256sum "$DECK" | awk '{print $1}')"

log "deck di lavoro : $DECK"
log "sha256 prima   : $before"

# L'helper di edit viene copiato dal wrapper come Z:\o.bat; lo script COM deve
# essere già presente nella condivisione.
cp -f "$ROOT_DIR/scripts/e2e/vm-edit.ps1" "$SHARE/e2e-edit.ps1"

cleanup() {
  [ "${PPTX_E2E_KEEP:-0}" = "1" ] && return 0
  rm -rf "$WORK" "$SHARE/e2e-edit.ps1" "$SHARE/e2e-out.txt"
}
trap cleanup EXIT

log "eseguo il wrapper --vnc con l'helper di edit..."
PPTX_VM_HELPER_SRC="$ROOT_DIR/scripts/e2e/vm-open-edit.bat" \
  "$WRAPPER" --vnc --timeout 300 "$DECK"

after="$(sha256sum "$DECK" | awk '{print $1}')"
log "sha256 dopo    : $after"
[ "$before" != "$after" ] || die "il file sull'host NON è cambiato dopo il salvataggio"

# Il marker deve essere dentro il .pptx (è uno zip): prova che PowerPoint ha
# davvero salvato il contenuto modificato e non solo toccato il file.
if ! unzip -p "$DECK" 'ppt/slides/slide1.xml' 2>/dev/null | grep -q "$MARKER"; then
  die "marker '$MARKER' non trovato nel deck salvato"
fi

log "PASS: modifica salvata dalla VM e visibile nel file host"
log "e2e explode: OK"
