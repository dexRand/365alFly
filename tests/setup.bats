#!/usr/bin/env bats
# Test di scripts/setup.sh — nessuna installazione reale: binari sostituiti da
# stub e distro forzata via env. Esegui con: bats tests/setup.bats

setup() {
  ROOT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT_DIR/scripts/setup.sh"

  TMP="$(mktemp -d)"
  mkdir -p "$TMP/bin"

  cat > "$TMP/bin/docker" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "compose" ] && [ "$2" = "version" ]; then exit 0; fi
exit 0
EOF
  chmod +x "$TMP/bin/docker"

  printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/xfreerdp-fake"
  chmod +x "$TMP/bin/xfreerdp-fake"

  PATH="$TMP/bin:$PATH"
  export PATH
  export PPTX_DOCKER_BIN="docker"
  export PPTX_FREERDP_BIN="xfreerdp-fake"
  export PPTX_KVM_DEV="/dev/null"
}

teardown() { rm -rf "$TMP"; }

setup_script() { run "$SCRIPT" "$@"; }

# --- help / usage -----------------------------------------------------------

@test "--help esce 0 e mostra l'uso" {
  setup_script --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Uso:"* ]]
}

@test "opzione sconosciuta: errore (exit 2)" {
  setup_script --wat
  [ "$status" -eq 2 ]
  [[ "$output" == *"opzione sconosciuta"* ]]
}

# --- --check ----------------------------------------------------------------

@test "--check con tutto presente esce 0" {
  setup_script --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK]"*"docker"* || "$output" == *"docker"*"[OK]"* ]]
}

@test "--check senza docker esce 1 e lo segnala" {
  export PPTX_DOCKER_BIN="no-such-docker-xyz"
  setup_script --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"docker"* ]]
}

@test "--check senza FreeRDP esce 1 e lo segnala" {
  export PPTX_FREERDP_BIN="no-such-freerdp-xyz"
  export PPTX_SETUP_FREERDP_FALLBACKS=""
  setup_script --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"FreeRDP"* || "$output" == *"freerdp"* ]]
}

@test "--check senza KVM esce 1 e lo segnala" {
  export PPTX_KVM_DEV="/no/such/kvm"
  setup_script --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"KVM"* ]]
}

# --- --dry-run / mappatura distro -------------------------------------------

@test "--dry-run su Arch pianifica pacman con docker/compose/freerdp" {
  export PPTX_SETUP_OS_ID="arch" PPTX_SETUP_OS_LIKE=""
  setup_script --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"pacman"* ]]
  [[ "$output" == *"docker"* ]]
  [[ "$output" == *"docker-compose"* ]]
  [[ "$output" == *"freerdp"* ]]
}

@test "--dry-run su Debian pianifica apt con docker.io e freerdp3" {
  export PPTX_SETUP_OS_ID="debian" PPTX_SETUP_OS_LIKE=""
  setup_script --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"apt-get"* ]]
  [[ "$output" == *"docker.io"* ]]
  [[ "$output" == *"freerdp3"* ]]
}

@test "--with-dev aggiunge shellcheck e bats" {
  export PPTX_SETUP_OS_ID="arch" PPTX_SETUP_OS_LIKE=""
  setup_script --dry-run --with-dev
  [ "$status" -eq 0 ]
  [[ "$output" == *"shellcheck"* ]]
  [[ "$output" == *"bats"* ]]
}

@test "senza --with-dev non propone shellcheck/bats" {
  export PPTX_SETUP_OS_ID="arch" PPTX_SETUP_OS_LIKE=""
  setup_script --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" != *"shellcheck"* ]]
  [[ "$output" != *"bats"* ]]
}

@test "distro sconosciuta: errore con guida manuale" {
  export PPTX_SETUP_OS_ID="plan9" PPTX_SETUP_OS_LIKE=""
  setup_script --dry-run
  [ "$status" -ne 0 ]
  [[ "$output" == *"non supportata"* || "$output" == *"non riconosciuta"* || "$output" == *"manuale"* ]]
}
