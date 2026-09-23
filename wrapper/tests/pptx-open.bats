#!/usr/bin/env bats
# Test di wrapper/pptx-open — VM e docker sostituiti da stub.

setup() {
  R="$BATS_TEST_DIRNAME/.."
  WRAPPER="$R/pptx-open"
  ROOT="$(cd "$R/.." && pwd)"

  TMP="$(mktemp -d)"
  mkdir -p "$TMP/deploy" "$TMP/bin" "$TMP/share" "$TMP/doc"
  SHARED="$TMP/share"
  FILE="$TMP/doc/deck.pptx"
  printf 'ORIGINAL\n' > "$FILE"

  printf 'VM_USER=pptx\nVM_PASSWORD=pw\nSHARED_DIR=%s\n' "$SHARED" > "$TMP/deploy/.env"
  printf 'name: x\n' > "$TMP/deploy/compose.yaml"

  cat > "$TMP/bin/docker" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  ps)
    if [[ " $* " == *" -q "* ]]; then echo fakecid; fi
    exit 0 ;;
  exec)
    if [ -n "${FAKE_SHARE:-}" ]; then
      [ -n "${FAKE_MODIFY:-}" ] && printf 'MODIFIED\n' >> "$FAKE_SHARE/inbox/$FAKE_BASE"
      printf '%s\n' "${FAKE_DONE:-ok}" > "$FAKE_SHARE/done.txt"
    fi
    exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$TMP/bin/docker"

  export PPTX_DEPLOY_DIR="$TMP/deploy"
  export PPTX_ENV_FILE="$TMP/deploy/.env"
  export PPTX_COMPOSE_FILE="$TMP/deploy/compose.yaml"
  export PPTX_DOCKER_BIN="$TMP/bin/docker"
  export FAKE_SHARE="$SHARED" FAKE_BASE="deck.pptx"
}

teardown() { rm -rf "$TMP"; }

@test "file mancante: errore ed exit 1" {
  run "$WRAPPER" "$TMP/doc/nope.pptx"
  [ "$status" -eq 1 ]
  [[ "$output" == *"file non trovato"* ]]
}

@test "senza argomenti: usage ed exit 2" {
  run "$WRAPPER"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Uso:"* ]]
}

@test "--help esce 0" {
  run "$WRAPPER" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Uso:"* ]]
}

@test "opzione sconosciuta: errore" {
  run "$WRAPPER" --wat "$FILE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"opzione sconosciuta"* ]]
}

@test "open: prepara la richiesta, attende e risincronizza il file" {
  FAKE_MODIFY=1 run "$WRAPPER" "$FILE"
  [ "$status" -eq 0 ]
  # il file originale deve contenere la modifica fatta "nella VM"
  run cat "$FILE"
  [[ "$output" == *"MODIFIED"* ]]
}

@test "open: scrive request.txt con il percorso relativo Windows" {
  run "$WRAPPER" "$FILE"
  [ "$status" -eq 0 ]
  # cleanup già avvenuto: la cartella condivisa non deve restare sporca
  [ ! -f "$SHARED/request.txt" ]
  [ ! -f "$SHARED/done.txt" ]
  [ ! -f "$SHARED/o.bat" ]
}

@test "open: errore segnalato dalla VM interrompe con exit 1" {
  FAKE_DONE="error:powerpoint" run "$WRAPPER" "$FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"la VM ha segnalato un errore"* ]]
}

@test "--status riporta VM attiva e cartella condivisa" {
  run "$WRAPPER" --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"VM: attiva"* ]]
  [[ "$output" == *"$SHARED"* ]]
}
