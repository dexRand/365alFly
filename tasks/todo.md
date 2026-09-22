# Task List — pptx-open (365alFly)

Stato del progetto: 🚧 Fase 0 in corso. Aggiorna le checkbox solo quando il
task è verificato (acceptance criteria + Definition of Done + gate di
fedeltà dove indicato).

## Phase 0 — Intake environmentale

- [x] Task 1: Probe ambiente host
  - Acceptance: `docs/environment.md` scritto con host, kernel, WSL2,
    /dev/kvm/nested virt, Docker/Podman, libvirt, FreeRDP, display.
  - Verify: file esistente e compilato con i comandi reali eseguiti
    (output dei probe allegati).
  - Files: `docs/environment.md`, `scripts/probe-env.sh` (se serve).
  - Volume: M.
- [x] Task 2: Requisiti WinApps da fonte ufficiale
  - Acceptance: `winapps-org/winapps` clonato, doc ufficiale letta,
    requisiti (ISO, RAM/disk, licenza, comandi) riportati con citazione.
  - Verify: sezione source-cited in `docs/environment.md` con link alla doc.
  - Files: `docs/environment.md`, `winapps-baseline/`.
  - Volume: M.
- [x] Task 3: Matrice di test pronta
  - Acceptance: tutte le presentazioni di `docs/TEST_MATRIX.md` disponibili
    in `winapps-baseline/test_files/`; riferimento nativo Windows individuato.
  - Verify: elenco file presenti + come gli snippet testuali della matrice
    vengono generati.
  - Files: `winapps-baseline/test_files/`, `docs/TEST_MATRIX.md`.
  - Volume: M.

**Checkpoint 0** (far fallire presto):
- [x] `docs/environment.md` scritto, blocchi documentati
- [x] Requisiti WinApps da fonte ufficiale
- [x] Blocchi virt risolti / decisione alternativa documentata

## Phase 1 — Baseline WinApps + gate di fedeltà

- [ ] Task 4: Provisioning VM Windows + Office
  - Acceptance: golden image con Office attivato eseguendo la procedura
    ufficiale WinApps; nessun segreto/licenza in repo.
  - Verify: la VM si avvia e PowerPoint parte; immagine privata documentata.
  - Files: `winapps-baseline/`.
  - Volume: L.
- [ ] Task 5: Primo end-to-end "apertura semplice"
  - Acceptance: una slide semplice della matrice apre via WinApps; screenshot
    catturato; confronto col riferimento nativo.
  - Verify: screenshot in `winapps-baseline/captures/` + verdetto.
  - Files: `winapps-baseline/captures/`, `docs/TEST_MATRIX.md`.
  - Volume: M.
- [ ] Task 6: Matrice di fedeltà completa
  - Acceptance: tutti i test della matrice eseguiti, screenshot raccolti,
    esito compilato.
  - Verify: checkbox esito in `docs/TEST_MATRIX.md`.
  - Files: `docs/TEST_MATRIX.md`.
  - Volume: L.

**Checkpoint 1 — GATE DI FEDELTÀ** (il criterio vero del progetto):
- [ ] Tutti i test senza differenze visibili (o minori giustificate)
- [ ] Differenze investigate prima sul lato qualità RDP
- [ ] Verdetto documentato

## Phase 2 — Wrapper disposable `pptx-open`

- [ ] Task 7: Misura boot cold vs warm
  - Acceptance: tempi reali misurati e riportati; decisione
    persistente-disposable presa con i dati.
  - Verify: numeri in `tasks/plan.md` o `docs/`.
  - Files: `docs/`, `tasks/plan.md`.
  - Volume: S.
- [ ] Task 8: Contratto CLI `pptx-open`
  - Acceptance: flag, exit code, messaggi d'errore, lock definiti e
    testati (bats).
  - Verify: `bats` verde sui test del contratto.
  - Files: `wrapper/`, `wrapper/tests/`.
  - Volume: S.
- [ ] Task 9: Implementazione wrapper
  - Acceptance: `pptx-open file.pptx` avvia/riusa VM, apre seamless,
    attende chiusura, sincronizza `.pptx`, fa cleanup. shellcheck pulito,
    bats verde.
  - Verify: `shellcheck wrapper/*.sh`; `bats wrapper/tests/`.
  - Files: `wrapper/`, `wrapper/tests/`.
  - Volume: M.
- [ ] Task 10: Test "explode" end-to-end
  - Acceptance: open → modifica → salva → chiudi → file aggiornato su host →
    ambiente rimosso → ri-apertura pulita.
  - Verify: sequenza documentata e green.
  - Files: `wrapper/tests/`, `docs/`.
  - Volume: M.

**Checkpoint 2:**
- [ ] `pptx-open` end-to-end funzionante (Fase 3 piano strategico)
- [ ] Nessun container/VM morti accumulati
- [ ] Decisione persistente/disposable documentata

## Phase 3 — Wine (condizionale)

- [ ] Task 11 (condizionale): POC Wine solo se blocco concreto in Fase 2
  - Acceptance: stesso gate di fedeltà; time-box di poche ore; report onesto.
  - Files: `wine-poc/`.
  - Volume: L.

## Verifica finale (docs/ACCEPTANCE.md)

- [ ] Tutti i criteri di accettazione finali spuntati con evidenze.