# pptx-open

Comando Linux-nativo per aprire `.pptx` con Microsoft PowerPoint **reale**
(non LibreOffice/OnlyOffice), con fedeltà di rendering identica a Windows,
in un ambiente disposable.

```
pptx-open ./presentazione.pptx
```

## Perché non Wine

Office 365 sotto Wine è storicamente instabile: si rompe a ogni
aggiornamento automatico del click-to-run, e le aree più critiche per la
fedeltà (SmartArt, animazioni, transizioni, font substitution) sono proprio
i punti deboli del layer di emulazione GDI/Direct2D/DirectWrite. Non esiste
un'immagine Docker "Wine + Office 365" pubblica e mantenuta. Wine è
rivalutato solo *dopo* la baseline (Fase 4 condizionale, vedi
`AGENT_PLAN.md`).

## Avvio rapido (Linux nativo)

Il percorso immediato — Windows + PowerPoint reali, accessibili via **VNC web**
(o RDP) — è automatizzato in `deploy/`:

```bash
# 1) prerequisiti host (Arch/CachyOS): docker + KVM
sudo pacman -S --needed docker qemu-full freerdp
sudo systemctl enable --now docker && sudo usermod -aG docker "$USER"

# 2) init (credenziali casuali) e avvio
scripts/pptx-deploy.sh init
scripts/pptx-deploy.sh up
scripts/pptx-deploy.sh url     # apri http://127.0.0.1:8006/ nel browser
```

Credenziali, chiavi di licenza e risorse si cambiano solo in `deploy/.env`
(gitignored, chmod 600). Guida completa: `docs/deploy.md`; decisione
architetturale: `docs/adr/0001-container-powerpoint-e-config-env.md`.

## Architettura scelta

Baseline: **WinApps** (https://github.com/winapps-org/winapps) — Windows
reale, integrazione seamless via FreeRDP, backend Docker/Podman
(attualmente: immagine `dockur/windows`, che gira QEMU+KVM) o libvirt.
Fedeltà garantita perché è PowerPoint vero su Windows vero.

- Host: Linux nativo (oggi CachyOS/Arch; la soluzione dev'essere agnostica:
  Docker/Podman/libvirt, X11/Wayland/WSLg). WSL2 + Docker è stato l'ambiente
  di sviluppo iniziale, ora non più il target.
- VM: Windows 11 LTSC 2024 (24H2/26100) — migrata dalla Pro 25H2 il
  2026-09-22 perché la 25H2 interrompeva la fase RDP di licensing (vedi la
  nota tecnica sotto). In `deploy/` è il default `WINDOWS_VERSION=11l`.
- Client RDP: FreeRDP 3 (`xfreerdp3`) in modalità seamless (RemoteApp).
- Referenza nativa: PowerPoint reale sul Windows host della macchina di
  sviluppo.

Il percorso di accesso **immediato** (Task 4, indipendente dal seamless) è il
container `dockur/windows` avviato da `deploy/`: web-VNC su `127.0.0.1:8006` e
RDP su `3389`, con Office installato automaticamente dall'Office Deployment
Tool. La stessa VM alimenterà il seamless WinApps in Fase 2.

Repos/deve upstream pinnati in `winapps-baseline/README.md`.

## Stato attività

| # | Attività | Stato | Evidenza |
|---|----------|-------|----------|
| 1 | Probe ambiente host | ✅ fatto | `docs/environment.md` |
| 2 | Requisiti WinApps da fonte ufficiale | ✅ fatto | `docs/environment.md` (source-cited) |
| 3 | Matrice di test pronta | ✅ fatto | `winapps-baseline/test_files/` (13 deck), 25 PNG di riferimento nativo in `winapps-baseline/captures/native/` |
| 4 | Provisioning VM Windows + Office | 🔶 in corso | docker installato su Arch; container `pptx-open-windows` avviato, **Windows 11 LTSC in installazione**; Office via ODT al termine |
| 5–6 | Apertura + gate di fedeltà | ⛔ bloccata | in attesa del boot della VM |
| 7–10 | Wrapper `pptx-open` | ⏳ in coda | Fase 2 |

Checkpoint 0 (intake ambiente) chiuso. Dettagli operativi in
`tasks/todo.md` e `tasks/plan.md`.

### Nota tecnica RDP (2026-09-22)

La VM Win11 25H2 interrompe la connessione tra licenza e installazione
sessione: `BB_ERROR_BLOB` + `close notify`, identico con `mstsc` e
`xfreerdp3`. Individuato con FreeRDP `-multitransport` (supera la licenza,
il server chiude subito dopo il Demand Active). Riferimenti: FreeRDP
issue #10864 (Win11/Server2025 + RDP TCP bug), KB5070311 (bug RemoteApp
Dec-2025). Provate senza esito varie combinazioni client
(`-multitransport`, `-gfx`, `-rfx`, `/bpp:16`): l'interruzione avviene lato
server, identica con `mstsc`. **Decisione (2026-09-22): base migrata a
Windows 11 LTSC 2024 (`VERSION: "11l"`, 24H2/26100)** — build matura,
RemoteApp/RDP verificati, iso 4.7 GB.

## Come riprodurre (Task 4 finora)

> **Percorso consigliato su Linux nativo:** `deploy/` + `scripts/pptx-deploy.sh`
> (vedi *Avvio rapido* e `docs/deploy.md`). La procedura manuale WinApps qui
> sotto resta valida per il seamless (Fase 2) e come riferimento; i comandi
> `apt` erano per l'ambiente WSL2/Ubuntu.

1. **Dipendenze host** (requisiti: KVM, ~14 GB RAM, ~40 GB disco):

   ```bash
   sudo apt install -y docker.io xrdp xfreerdp3 shellcheck bats unzip aria2 cpu-checker
   sudo usermod -aG docker "$USER"
   sudo kvm-ok   # "KVM acceleration can be used"
   ```

2. **Config privata** (MAI committata — i segreti vivono solo qui):

   ```bash
   mkdir -p ~/.config/winapps
   cp winapps-baseline/compose.template.yaml ~/.config/winapps/compose.yaml
   # -> impostare USERNAME/PASSWORD reali in compose.yaml (chmod 600)
   # template pubblico: winapps-baseline/compose.template.yaml
   ```

3. **OEM post-install** (RDPApps.reg per RemoteApp: disabilita l'allowlist):

   ```bash
   wa_from=winapps-baseline/winapps
   cp -r "$wa_from"/oem ~/.config/winapps/oem
   ```

4. **Config WinApps** (`~/.config/winapps/winapps.conf`, chmod 600):

   ```text
   WAFLAVOR="docker"
   RDP_IP="127.0.0.1"
   RDP_PORT="3389"
   RDP_USER="<USERNAME>"
   RDP_PASS="<PASSWORD>"
   CERT_PATH="/cert:tofu"
   RDP_FLAGS="/cert:tofu /sound /microphone +home-drive"
   ```

5. **Avvio VM e attesa installazione:**

   ```bash
   docker compose --file ~/.config/winapps/compose.yaml up -d
   docker logs -f WinApps   # attendere "Windows started successfully"
   ```

6. **Test RDP/Rail (seamless):**

   ```bash
   xfreerdp3 /u:<USERNAME> /p:<PASSWORD> /v:127.0.0.1:3389 \
     /cert:tofu /app:program:notepad.exe /size:800x600 /timeout:20
   ```

I certificati TLS/RDPvengono salvati in `~/.config/freerdp/` (tofu:
cancellare `server/127.0.0.1_3389.pem` dopo ogni cambio certificato VM).

## Segreti e licenze

- Credenziali VM, chiavi e attivazioni: solo in `deploy/.env` (chmod 600,
  gitignored) per il percorso container, e in `~/.config/winapps/` per il
  seamless. Mai nel repo.
- Windows: non attivato per default (watermark "Attiva Windows" accettato in
  sviluppo); `WINDOWS_KEY` in `.env` se disponibile.
- Office: `OFFICE_KEY` in `.env` fa attivare automaticamente Office LTSC
  (Volume); senza key si usa il trial Microsoft 365 (`o365`). Senza key Office
  resta in sola lettura.
- **Nessun attivatore di pirateria (MAS/HWID)**: non implementato. Vedi
  `docs/adr/0001-container-powerpoint-e-config-env.md`.

## Gate di fedeltà

Una funzionalità NON è fatta quando "PowerPoint si apre": è fatta solo
quando il rendering è indistinguibile da PowerPoint su Windows. Verdetto
documentato in `docs/TEST_MATRIX.md` con screenshot in
`winapps-baseline/captures/` (nativi committati; render della VM
disposable, ignorati da git).

## Struttura

```
/AGENT_PLAN.md          — piano per l'agente, fasi e gate
/tasks/plan.md          — piano di implementazione (task, rischi, decisioni)
/tasks/todo.md          — checklist operativa dei task
/docs/deploy.md         — guida+specifica ambiente container (Task 4)
/docs/adr/              — decisioni architetturali (ADR)
/docs/TEST_MATRIX.md    — presentazioni di test e criteri di fedeltà
/docs/ACCEPTANCE.md     — criteri di accettazione finali
/deploy/                — compose + .env + OEM per Windows+PowerPoint (dockur)
/scripts/pptx-deploy.sh — CLI init/doctor/office-config/up/down/reset
/tests/deploy.bats      — test della CLI (bats)
/winapps-baseline/      — test decks, baseline PNG, template compose, fonts
/wrapper/               — script pptx-open (Fase 2)
/wine-poc/              — eventuale POC Wine opzionale (condizionale)
```