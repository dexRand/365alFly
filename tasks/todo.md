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
  - Stato al 2026-09-22: VM Win11 Pro (build 26200/25H2) installata e
    avviata via dockur; RDP (3389) fine-tuning: NLA ok ma il server
    interrompe la sessione tra license e Demand Active
    (`BB_ERROR_BLOB`, `close notify`); identico con mstsc. Ipotesi: 25H2
    con KB Dec-2025 ha bug RDP/RemoteApp lato server (vedi FreeRDP #10864,
    KB5070311). Tentativi senza esito parte client: `-multitransport`
    (supera la licenza ma il server chiude dopo il Demand Active), `-gfx`,
    `-rfx`, `/bpp:16`, `/timeout` ampi. **Decisione: base migrata a
    Windows 11 LTSC 2024 (`VERSION: "11l"`, 24H2/26100)**, volume ricreato,
    installazione in corso alla chiusura sessione. Da fare al rientro:
    validare RDP full-desktop + RemoteApp(`notepad`), validare RAIL con
    RDPApps.reg, installare Manrope nella VM, capire licenza Office.
    Office: licenza NON ancora disponibile (utente ha scelto
    di procedere col resto). Windows: resta non attivato, watermark
    accettato finché non arriva il gate finale. Installazioni root richieste
    (es. freerdp2 fallback) vanno fatte dall'utente (sudo non è passwordless).
  - Stato al 2026-09-23 (Arch nativo): predisposto il percorso **container
    diretto VNC/RDP** in `deploy/` (`dockur/windows` + Office via Office
    Deployment Tool): CLI `scripts/pptx-deploy.sh init|doctor|office-config|
    prepare|up|down|reset|logs|status|url`; 21 test `bats` verdi, `shellcheck`
    pulito; `deploy/.env` generato con credenziali casuali (chmod 600,
    gitignored). Da fare: `sudo pacman -S docker qemu-full freerdp`, login
    nuovamente per il gruppo docker, poi `scripts/pptx-deploy.sh up` e verifica
    runtime (desktop VNC + PowerPoint). Vedi `docs/deploy.md` e ADR 0001.
  - Avanzamento 2026-09-23: `docker`, `docker-compose`, `freerdp`, `shellcheck`,
    `bats` installati via `pkexec` (polkit); immagine `dockurr/windows:6.05`
    scaricata; container avviato, Windows 11 LTSC in installazione. Applicato
    `chattr +C` alla directory del volume (mitigazione btrfs).
  - Runtime verificato: Windows 11 LTSC installato, desktop e autologin utente
    `pptx`; `install.bat` in esecuzione (ODT → Office `o365`, nessuna key →
    trial, **nessun MAS**); Windows Eval non attivato (atteso). Web UI senza
    login (`WEB_PROTECT=N`). Verifica attività: `docker stats` + crescita
    `data.img`. Da fare: attendere fine provisioning Office, aprire PowerPoint.
  - Cleanup host a fine progetto: rimuovere il sudoers temporaneo dell'agent
    (vedi sezione "Cleanup a fine progetto").
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

## Cleanup a fine progetto (robaccia lasciata sull'host)

- [ ] Rimuovere il sudoers temporaneo creato per l'agent:
      `sudo rm /etc/sudoers.d/99-pptx-open-agent`
      (era stato aggiunto il 2026-09-23 per evitare i prompt polkit durante il
      provisioning; va togliato quando il progetto è finito.)
- [ ] `scripts/pptx-deploy.sh reset --yes` se non serve più la VM Windows.