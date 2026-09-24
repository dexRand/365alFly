# Task List — pptx-open (365alFly)

Stato del progetto: 🚀 Fase 1 chiusa (gate di fedeltà 21/25 byte-identiche),
Fase 2 in corso. Aggiorna le checkbox solo quando il task è verificato
(acceptance criteria + Definition of Done + gate di fedeltà dove indicato).

> CI: `.github/workflows/ci.yml` (shellcheck + bats) è versionato e partirà su
> push/PR quando la repo diventerà pubblica.

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
  - Garanzia "install pulita" VERIFICATA 2026-09-23: eseguito un `down -v` +
    `up` reale (~22 min); a installazione fresca, aprendo PowerPoint senza
    alcun Esc manuale il popup "Sign in to set up Office" NON compare
    (`nagkiller.vbs` in Startup + Run). Bug trovato dal test: commento inline
    in `.env` (`WINDOWS_VERSION`) rompeva `VERSION` → rimosso e bloccato da un
    test dedicato.
  - Riepilogo 2026-09-24: provisioning verificato e funzionante (Windows 11
    LTSC, Office installato via ODT, OEM trust/sessione/RemoteApp, prompt
    killer). Validati RDP full-desktop e RemoteApp/RAIL (ora modalità default
    del wrapper). Font Manrope installati via `deploy/oem/fonts/`. Resta aperta
    solo la licenza/attivazione Office (non disponibile → trial/non attivato;
    non blocca il gate di fedeltà).
- [x] Task 5: Primo end-to-end "apertura semplice"
  - Acceptance: una slide semplice della matrice apre via WinApps; screenshot
    catturato; confronto col riferimento nativo.
  - Verify: screenshot in `winapps-baseline/captures/` + verdetto.
  - Files: `winapps-baseline/captures/`, `docs/TEST_MATRIX.md`.
  - Volume: M.
  - FATTO 2026-09-23: `fonts.pptx` aperto da `Z:\test_files\` in PowerPoint
    (GUI visibile via VNC, titolo "Saved to Z: Drive"), slide 1/7 renderizzata.
- [x] Task 6: Matrice di fedeltà completa
  - Acceptance: tutti i test della matrice eseguiti, screenshot raccolti,
    esito compilato.
  - Verify: checkbox esito in `docs/TEST_MATRIX.md`.
  - Files: `docs/TEST_MATRIX.md`.
  - Volume: L.
  - FATTO 2026-09-23: 13 deck esportati in PNG 1600×900 dalla VM (PowerPoint
    COM) e confrontati coi reference nativi → 21/25 slide byte-identiche, 4 con
    sole differenze di antialiasing testo. Verdetto in `docs/TEST_MATRIX.md`.

**Checkpoint 1 — GATE DI FEDELTÀ** (il criterio vero del progetto):
- [x] Tutti i test senza differenze visibili (o minori giustificate)
- [x] Differenze investigate prima sul lato qualità RDP
- [x] Verdetto documentato

## Phase 2 — Wrapper disposable `pptx-open`

- [x] Task 7: Misura boot cold vs warm
  - Acceptance: tempi reali misurati e riportati; decisione
    persistente-disposable presa con i dati.
  - Verify: numeri in `tasks/plan.md` o `docs/`.
  - Files: `docs/`, `tasks/plan.md`.
  - Volume: S.
  - MISURATO 2026-09-24:
    - **cold** (ambiente ricreato da zero, `down -v` + `up`, ISO+Office):
      ~**22 min** (misura reale 2026-09-23, vedi Task 4).
    - **warm** (container ricreato, Windows già nel volume): **~37 s** fino al
      desktop utilizzabile (marker dockur "Windows started successfully" a
      ~10 s + ~27 s per OS/RDP). Misurato con probe funzionale.
  - DECISIONE: **container disposable per sessione, volume "golden"
    persistente**. `pptx-open --kill` fa `compose down` (container rimosso,
    ~37 s a riavvio); il `down -v` completo costa ~22 min e va riservato al
    reset esplicito. Attivazione/licenza Office restano nel volume, mai in repo.
- [x] Task 8: Contratto CLI `pptx-open`
  - Acceptance: flag, exit code, messaggi d'errore, lock definiti e
    testati (bats).
  - Verify: `bats` verde sui test del contratto.
  - Files: `wrapper/`, `wrapper/tests/`.
  - Volume: S.
  - FATTO: contratto in `docs/wrapper.md`; `--no-wait/--kill/--timeout/--status`;
    exit 0/1/2; 9 test bats.
- [x] Task 9: Implementazione wrapper
  - Acceptance: `pptx-open file.pptx` avvia/riusa VM, apre seamless,
    attende chiusura, sincronizza `.pptx`, fa cleanup. shellcheck pulito,
    bats verde.
  - Verify: `shellcheck wrapper/*.sh`; `bats wrapper/tests/`.
  - Files: `wrapper/`, `wrapper/tests/`.
  - Volume: M.
  - FATTO: implementato in tre modi — seamless RDP RemoteApp (default),
    desktop RDP (`--desktop`), VNC + cartella condivisa (`--vnc`); vedi
    `docs/wrapper.md`. shellcheck pulito, 9/9 bats.
- [x] Task 10: Test "explode" end-to-end
  - Acceptance: open → modifica → salva → chiudi → file aggiornato su host →
    ambiente rimosso → ri-apertura pulita.
  - Verify: sequenza documentata e green.
  - Files: `wrapper/tests/`, `docs/`.
  - Volume: M.
  - FATTO 2026-09-24: script riproducibile `scripts/e2e-explode.sh` (helper
    in-VM `scripts/e2e/` con PowerPoint COM). Sequenza verificata:
    1. open→edit→save→close: SHA del file host cambiato e marker
       `E2E-OK-365alFly` presente dentro il `.pptx` salvato;
    2. `docker compose down`: container rimosso, volume "golden" conservato;
    3. il file host sopravvive (SHA invariato);
    4. `up` (~37 s) + riapertura pulita: e2e di nuovo verde.
    Difetti trovati e corretti durante il test (vedi commit):
    - trigger `Z:\o.bat` bloccato dal warning di sicurezza → `LowRiskFileTypes`
      nel provisioning (`deploy/oem/configure-trust.bat`);
    - `ensure_vm` considerava pronta la VM al marker QEMU (~10 s) mentre il
      desktop serve ~37 s → aggiunta `wait_guest_ready` (porta RDP).

**Checkpoint 2:**
- [x] `pptx-open` end-to-end funzionante (Fase 3 piano strategico) — e2e explode
      verde (`scripts/e2e-explode.sh`)
- [x] Nessun container/VM morti accumulati — un solo container/volume gestito
- [x] Decisione persistente/disposable documentata (Task 7: disposable per
      sessione, volume golden persistente)

## Phase 3 — Wine (condizionale)

- [x] Task 11 (condizionale): POC Wine solo se blocco concreto in Fase 2
  - Acceptance: stesso gate di fedeltà; time-box di poche ore; report onesto.
  - Files: `wine-poc/`.
  - Volume: L.
  - NON ATTIVATO: la Fase 2 è completata con WinApps/RDP senza blocchi
    concreti; la condizione di ingresso non si è verificata. Wine resta
    l'opzione esplorativa in coda, mai la strada primaria.

## Verifica finale (docs/ACCEPTANCE.md)

- [x] Tutti i criteri di accettazione finali spuntati con evidenze
      (vedi `docs/ACCEPTANCE.md`).

## Cleanup a fine progetto (robaccia lasciata sull'host)

- [x] Rimosso il sudoers temporaneo creato per l'agent:
      `/etc/sudoers.d/99-pptx-open-agent` (rimosso il 2026-09-24).
- [ ] `scripts/pptx-deploy.sh reset --yes` se non serve più la VM Windows.
      **Azione distruttiva**: elimina il volume "golden" (~22 min per
      ricrearlo). Lasciata all'utente; il container è già disposable via
      `pptx-open --kill`. Stato attuale: container/volume presenti e funzionanti.