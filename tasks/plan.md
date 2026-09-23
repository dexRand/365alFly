# Implementation Plan: pptx-open (365alFly)

## Overview

`pptx-open file.pptx` apre un `.pptx` con Microsoft PowerPoint **reale**
(non LibreOffice/OnlyOffice) su Linux con rendering indistinguibile da
Windows, in un ambiente disposable. Baseline: WinApps (Windows reale in
Docker/Podman o VM libvirt + integrazione seamless via FreeRDP). Wine è
un'esplorazione opzionale solo in coda, mai la strada primaria.

Unico criterio di successo: "la presentazione appare identica a come appare
in PowerPoint su Windows". Verdetto di fedeltà basato su confronto
screenshot della matrice in `docs/TEST_MATRIX.md`, non su "si apre".

## Decisioni architetturali

1. **Baseline WinApps, non Wine.** GLi layer GDI/Direct2D/DirectWrite di
   Wine sono proprio i punti deboli per SmartArt/animazioni/font
   substitution, e Office creto di sicurezza si rompe a ogni aggiornamento
   click-to-run. WinApps usa Windows reale: la fedeltà è data, non emulata.
   (Riferimento: `docs/` e README; validare su docs ufficiali WinApps in
   Fase 0 — skill `source-driven-development`.)
2. **Gate di fedeltà come unico criterio di "done".** Nessun task è
   completato se la renderizzazione non è indistinguibile dal riferimento
   Windows. Anti-rationalization: "PowerPoint si apre" NON è done.
3. **Disposable con decisione misurata.** VM persistente in background vs
   VM distrutta dopo ogni sessione: la scelta si fa sul tempo di boot reale
   misurato (Fase 2), non per principio.
4. **Licenza/attivazione Office solo nella golden image**, mai nell'immagine
   pubblica né in repo (skill `security-and-hardening`).
5. **Wrapper bash testato con bats + shellcheck** (skil `api-and-interface-design`
   + `test-driven-development`), CI su GitHub Actions.

## Task List

### Phase 0 — Intake environmentale (fail fast, prerequisito hard)

- **Task 1: Probe ambiente host** — documentare host, kernel, WSL2,
  disponibilità di /dev/kvm / nested virt, Docker/Podman, libvirt/QEMU,
  client FreeRDP, display (X11/WSLg). Output: `docs/environment.md`.
- **Task 2: Requisiti WinApps da fonte ufficiale** — clonare
  `winapps-org/winapps`, leggere la doc ufficiale, riportare requisiti
  (ISO Windows, licenza Office, RAM/disk minimi, comandi di setup).
  Output: note citate in `docs/environment.md` + sezione source-cited.
- **Task 3: Matrice di test pronta** — preparare/raccogliere le
  presentazioni di prova di `docs/TEST_MATRIX.md` e un riferimento nativo
  Windows per il confronto (dove disponibile).

**Checkpoint 0:**
- [ ] `docs/environment.md` scritto con i blocchi documentati
- [ ] Requisiti WinApps verificati da fonte ufficiale
- [ ] Blocchi di virtualizzazione risolti o decisione alternativa presa

### Phase 1 — Baseline WinApps + gate di fedeltà

- **Task 4: Provisioning VM Windows + Office** — seguire procedura ufficiale
  WinApps; golden image con Office attivato. **Nessun segreto in repo.**
  (skil `source-driven-development` + `security-and-hardening`.)
  Percorso container diretto VNC/RDP in `deploy/` (dockur/windows + ODT),
  config in `deploy/.env`; vedi `docs/deploy.md` e ADR 0001.
- **Task 5: Primo test end-to-end "apertura semplice"** — slide semplice
  (test #1 della matrice) aperta via WinApps, screenshot, confronto con
  riferimento nativo.
- **Task 6: Matrice completa di fedeltà** — eseguire tutti i test di
  `docs/TEST_MATRIX.md`, raccogliere screenshot WinApps vs nativo,
  compilare l'esito nel file.

**Checkpoint 1 (gate di fedeltà):**
- [ ] Tutti i test della matrice superati senza differenze visibili (o
      differenze minori giustificate)
- [ ] Eventuali differenze investigate prima tutto sul lato qualità RDP
- [ ] Verdetto documentato in `docs/TEST_MATRIX.md`

### Phase 2 — Wrapper disposable `pptx-open`

- **Task 7: Misura boot vs persistente** — misurare boo realtime della VM
  cold e warm; riportare i numeri e decidere persistente vs disposable
  con i dati.
- **Task 8: Contratto CLI `pptx-open`** — definire flag, exit code, error
  semantics (skil `api-and-interface-design`): `pptx-open file.pptx`,
  `--wait`, `--kill`, gestione file non esistenti, lock.
- **Task 9: Implementazione wrapper** — script bash che: avvia/riusa VM,
  apre il file in seamless mode, attende chiusura PowerPoint, verifica e
  sincronizza il `.pptx`, gestisce cleanup. TDD con bats, lint shellcheck.
- **Task 10: Test "explode" end-to-end** — sequenza Fase 3 del piano
  strategico: open → modifica → salva → chiudi → file aggiornato su host →
  ambiente rimosso → seconda apertura pulita.

**Checkpoint 2:**
- [ ] `pptx-open` funziona end-to-end (Fase 3 del piano strategico)
- [ ] Nessun container/VM morti accumulati
- [ ] Decisione persistente/disposable documentata con i numeri di boot

### Phase 3 — Wine (solo se serve, non fallback primario)

- **Task 11 (condizionale): POC Wine buono al boot/prestazioni** — solo se
  le Fasi 1-2 hanno un blocco concreto documentato. Time-box: poche ore.
  Stesso gate di fedeltà. Aspettativa realistica: bassa stabilità.

## Rischi e mitigazioni

| Rischio | Impatto | Mitigazione |
|---|---|---|
| `pptx-open` fornisce /dev/kvm/nested virt assente (spec. in WSL2) | Alto | Task 1 fail-fast; pipelining checkbox (HVP/QEMU) o VM libvirt su host fisico Linux |
| Display headless: niente X/Wayland nel ambiente target | Alto | Verificare WSLg/X server; FreeRDP può richiedere display server sul lato Linux |
| Riferimento nativo Windows non disponibile per il confronto | Medio | La macchina build è Windows: usare PowerPoint nativo sulla stessa macchina come riferimento |
| Uso eccessivo di indica aumento al boot VM | Medio | Misurare (Task 7) prima di decidere; snapshot/freeze per accorciare |
| Attivazione Office si rompe / immagine pubblica non autorizzata | Alto | Golden image privata; licenza mai in repo (Documenti di sicurezza) |
| FreeRDP degrado qualità (colori/font antialiasing) a bassa velocità | Medio | Indagare qualità RDP/GPU prima di dubitare dell'approccio (gate Fase 1) |
| Wine in Fase 4 accetta "funziona il più delle volte" | Medio | Gate di fedeltà identico; report onesto (docs/ACCEPTANCE.md) |

## Open Questions

1. Display path nel ambiente target: WSLg gestisce finestre seamless FreeRDP
   senza X server esterno? Va verificato in Fase 0.
2. Docker Desktop (backend WSL2) è disponibile? O Podman? I vincolo del
   progetto è Docker/Podman o libvirt.
3. Il riferimento nativo al confronto è il PowerPoint della stessa macchina
   Windows su cui gira opencode? Confermare che Office sia installato.
4. Automazione screenshot: come catturare deterministicamente gli screenshot
   RDP per il confronto (xwd/import, virtual display)? Da definire in Task 5.
5. Dimensione/risoluzione dello schermo virtuale Windows (affeta i layout).

## Definition of Done di progetto

Bar fixed per ogni task (vedi `.opencode/references/definition-of-done.md`):
- Correttezza: acceptance criteria soddisfatti; comportamento verificato a
  runtime; test nuovi che falliscono senza la change; niente regressioni.
- Qualità: nome-structure rivelano intenzione; no logica duplicata; no dead
  code; shellcheck pulito; bats verde.
- Integrazione: funziona con il resto del sistema; config/flags contabilizzati.
- Documentazione: interfacce pubbliche documentate; decisioni architetturali
  registrate (`docs/`, ADR quando serve).
- Fidelity gate: per le fasi di rendering, nessun "PowerPoint si apre" come
  prova; confronto screenshot obbligatorio.