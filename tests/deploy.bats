#!/usr/bin/env bats
# Test di scripts/pptx-deploy.sh — nessuna VM e nessun docker reale:
# docker è sostituito da uno stub. Esegui con: bats tests/deploy.bats

setup() {
  ROOT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$ROOT_DIR/scripts/pptx-deploy.sh"

  TMP_DIR="$(mktemp -d)"
  mkdir -p "$TMP_DIR/deploy/oem/office" "$TMP_DIR/bin" "$TMP_DIR/fonts"
  cp "$ROOT_DIR/deploy/.env.example" "$TMP_DIR/deploy/.env.example"
  cp "$ROOT_DIR/deploy/compose.yaml" "$TMP_DIR/deploy/compose.yaml"

  export PPTX_DEPLOY_DIR="$TMP_DIR/deploy"
  export PPTX_ENV_FILE="$TMP_DIR/deploy/.env"
  export PPTX_COMPOSE_FILE="$TMP_DIR/deploy/compose.yaml"
  export PPTX_FONTS_SRC="$TMP_DIR/fonts"
  # I requisiti reali restano 40 GiB/8 GiB; nei test la tmpdir è su tmpfs.
  export PPTX_MIN_FREE_GB=0
  export PPTX_MIN_RAM_GB=0

  CONFIG_XML="$PPTX_DEPLOY_DIR/oem/office/configuration.xml"
}

teardown() {
  rm -rf "$TMP_DIR"
}

deploy() { run "$SCRIPT" "$@"; }

# Scrive un .env minimale; $1 = righe extra (anche multi-riga).
write_env() {
  {
    printf 'VM_USER=pptx\n'
    printf 'VM_PASSWORD=secret123abc\n'
    printf '%s\n' "${1:-}"
  } > "$PPTX_ENV_FILE"
  chmod 600 "$PPTX_ENV_FILE"
}

install_fake_docker() {
  cat > "$TMP_DIR/bin/docker" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "compose" ] && [ "$2" = "version" ]; then exit 0; fi
printf 'DOCKER-COMPOSE %s\n' "$*"
exit 0
EOF
  chmod +x "$TMP_DIR/bin/docker"
  export PPTX_DOCKER_BIN="$TMP_DIR/bin/docker"
}

# --- init -------------------------------------------------------------------

@test "init crea .env con password generata e permessi 600" {
  deploy init
  [ "$status" -eq 0 ]
  [ -f "$PPTX_ENV_FILE" ]
  [ "$(stat -c '%a' "$PPTX_ENV_FILE")" = "600" ]

  local pw
  pw="$(sed -n 's/^VM_PASSWORD=//p' "$PPTX_ENV_FILE")"
  [ "${#pw}" -eq 24 ]
  [[ "$pw" =~ ^[A-Za-z0-9]{24}$ ]]
  ! grep -q '__GENERATE__' "$PPTX_ENV_FILE"
  grep -q '^VM_USER=pptx$' "$PPTX_ENV_FILE"
}

@test "init non sovrascrive .env esistente senza --force" {
  deploy init
  deploy init
  [ "$status" -ne 0 ]
  [[ "$output" == *"esiste già"* ]]
}

@test "init --force rigenera la password" {
  deploy init
  local first second
  first="$(sed -n 's/^VM_PASSWORD=//p' "$PPTX_ENV_FILE")"
  deploy init --force
  [ "$status" -eq 0 ]
  second="$(sed -n 's/^VM_PASSWORD=//p' "$PPTX_ENV_FILE")"
  [ "$first" != "$second" ]
}

@test "init rifiuta opzioni sconosciute" {
  deploy init --wat
  [ "$status" -ne 0 ]
  [[ "$output" == *"non riconosciuta"* ]]
}

# --- office-config ----------------------------------------------------------

@test "office-config senza .env fallisce con messaggio chiaro" {
  deploy office-config
  [ "$status" -ne 0 ]
  [[ "$output" == *".env non trovato"* ]]
}

@test "auto senza key sceglie Microsoft 365 (o365) senza attivazione" {
  write_env $'OFFICE_EDITION=auto\nOFFICE_KEY='
  deploy office-config
  [ "$status" -eq 0 ]
  grep -q '<Product ID="O365ProPlusRetail">' "$CONFIG_XML"
  grep -q 'Channel="Current"' "$CONFIG_XML"
  ! grep -q 'PIDKEY' "$CONFIG_XML"
  ! grep -q 'AUTOACTIVATE' "$CONFIG_XML"
}

@test "auto con key sceglie Office LTSC 2024 e abilita AUTOACTIVATE" {
  write_env $'OFFICE_EDITION=auto\nOFFICE_KEY=ABCDE-FGHIJ-KLMNO-PQRST-UVWXY'
  deploy office-config
  [ "$status" -eq 0 ]
  grep -q '<Product ID="ProPlus2024Volume" PIDKEY="ABCDE-FGHIJ-KLMNO-PQRST-UVWXY">' "$CONFIG_XML"
  grep -q 'Channel="PerpetualVL2024"' "$CONFIG_XML"
  grep -q 'AUTOACTIVATE' "$CONFIG_XML"
}

@test "office-config normalizza la key (minuscole e spazi)" {
  write_env $'OFFICE_EDITION=ltsc2021\nOFFICE_KEY=abcde fghij klmno pqrst uvwxy'
  deploy office-config
  [ "$status" -eq 0 ]
  grep -q 'PIDKEY="ABCDE-FGHIJ-KLMNO-PQRST-UVWXY"' "$CONFIG_XML"
  grep -q 'Channel="PerpetualVL2021"' "$CONFIG_XML"
}

@test "office-config rifiuta una key malformata" {
  write_env $'OFFICE_EDITION=ltsc2024\nOFFICE_KEY=TOOSHORT'
  deploy office-config
  [ "$status" -ne 0 ]
  [[ "$output" == *"OFFICE_KEY non valida"* ]]
  [ ! -f "$CONFIG_XML" ]
}

@test "office-config rifiuta un'edizione sconosciuta" {
  write_env $'OFFICE_EDITION=office95\nOFFICE_KEY='
  deploy office-config
  [ "$status" -ne 0 ]
  [[ "$output" == *"OFFICE_EDITION non valido"* ]]
}

@test "office-config esclude le app elencate in OFFICE_EXCLUDE" {
  write_env $'OFFICE_EDITION=o365\nOFFICE_EXCLUDE=Outlook,Teams'
  deploy office-config
  [ "$status" -eq 0 ]
  grep -q '<ExcludeApp ID="Outlook" />' "$CONFIG_XML"
  grep -q '<ExcludeApp ID="Teams" />' "$CONFIG_XML"
}

@test "office-config scrive un configuration.xml XML ben formato" {
  write_env $'OFFICE_EDITION=o365'
  deploy office-config
  [ "$status" -eq 0 ]
  run python3 -c 'import sys, xml.dom.minidom; xml.dom.minidom.parse(sys.argv[1])' "$CONFIG_XML"
  [ "$status" -eq 0 ]
}

@test "office-config scrive l'URL dell'ODT" {
  write_env $'OFFICE_EDITION=o365\nODT_URL=https://example.com/odt.exe'
  deploy office-config
  [ "$status" -eq 0 ]
  [ "$(cat "$PPTX_DEPLOY_DIR/oem/office/odt-url.txt")" = "https://example.com/odt.exe" ]
}

# --- prepare ----------------------------------------------------------------

@test "prepare con INSTALL_OFFICE=N non genera la config Office" {
  write_env $'INSTALL_OFFICE=N'
  deploy prepare
  [ "$status" -eq 0 ]
  [ ! -f "$CONFIG_XML" ]
}

@test "prepare copia i font TTF nella cartella OEM" {
  : > "$PPTX_FONTS_SRC/Manrope-VariableFont.ttf"
  write_env $'OFFICE_EDITION=o365'
  deploy prepare
  [ "$status" -eq 0 ]
  [ -f "$PPTX_DEPLOY_DIR/oem/fonts/Manrope-VariableFont.ttf" ]
}

@test "prepare crea la cartella condivisa e vi semina i deck di test" {
  mkdir -p "$TMP_DIR/seed"
  : > "$TMP_DIR/seed/alpha.pptx"
  export PPTX_SEED_SRC="$TMP_DIR/seed"
  write_env $'OFFICE_EDITION=o365\nSHARED_DIR=./shared'
  deploy prepare
  [ "$status" -eq 0 ]
  [ -f "$PPTX_DEPLOY_DIR/shared/test_files/alpha.pptx" ]
}

@test "prepare rispetta un SHARED_DIR assoluto" {
  local custom="$TMP_DIR/documenti"
  write_env "OFFICE_EDITION=o365
SHARED_DIR=$custom"
  deploy prepare
  [ "$status" -eq 0 ]
  [ -d "$custom" ]
}

# --- docker / up ------------------------------------------------------------

@test "up prepara l'OEM e avvia docker compose" {
  install_fake_docker
  write_env $'OFFICE_EDITION=o365'
  deploy up
  [ "$status" -eq 0 ]
  [[ "$output" == *"DOCKER-COMPOSE"* ]]
  [[ "$output" == *"up -d"* ]]
  [ -f "$CONFIG_XML" ]
}

@test "reset richiede --yes" {
  install_fake_docker
  write_env $'OFFICE_EDITION=o365'
  deploy reset
  [ "$status" -ne 0 ]
  [[ "$output" == *"--yes"* ]]
}

@test "reset --yes elimina il volume" {
  install_fake_docker
  write_env $'OFFICE_EDITION=o365'
  deploy reset --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"down --volumes"* ]]
}

@test "doctor fallisce se docker è assente ma riporta KVM" {
  export PPTX_DOCKER_BIN="$TMP_DIR/bin/definitely-not-here"
  deploy doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"docker: non trovato"* ]]
  [[ "$output" == *"KVM"* ]]
}

# --- dispatch ---------------------------------------------------------------

@test "comando sconosciuto fallisce con suggerimento" {
  deploy frobnicate
  [ "$status" -ne 0 ]
  [[ "$output" == *"comando sconosciuto"* ]]
}

@test "help elenca i comandi ed esce 0" {
  deploy help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Uso:"* ]]
  [[ "$output" == *"office-config"* ]]
}
