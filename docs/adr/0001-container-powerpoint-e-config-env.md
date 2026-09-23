# ADR 0001 — Ambiente PowerPoint: container dockur/windows diretto (VNC/RDP), config in `.env`

- Data: 2026-09-23
- Stato: accettata
- Contesto: Task 4 (provisioning VM Windows + Office), Fase 1

## Contesto

Il progetto richiede Microsoft PowerPoint reale su Linux con fedeltà Windows.
La baseline decisa è WinApps (Windows in container + FreeRDP seamless), ma il
primo obiettivo utile per l'utente è: **aprire il container e usare PowerPoint
subito, anche solo via VNC**. Serve inoltre automatizzare installazione Office
e gestione di credenziali/licenze da un unico punto modificabile.

L'host di sviluppo è ora Linux nativo (CachyOS/Arch) senza Docker, Podman,
QEMU, libvirt o FreeRDP installati, con `/dev/kvm` presente e scrivibile.

## Decisione

1. **Backend diretto `dockur/windows`** (immagine `dockurr/windows`, pin `6.05`)
   con QEMU+KVM, esposto via web-VNC (`8006`) e RDP (`3389`). È lo stesso
   backend di WinApps: l'integrazione seamless (Fase 2) riuserà la stessa VM,
   senza riscrivere il provisioning.
2. **Configurazione guidata da un solo `deploy/.env`** (gitignored,
   `chmod 600`): credenziali, risorse, rete, `SHARED_DIR`, edizione e chiavi.
   `deploy/compose.yaml` non contiene segreti (placeholder `${...}` +
   `--env-file`).
3. **Provisioning Office via OEM/ODT**: `deploy/oem/install.bat` è eseguito da
   dockur a fine installazione; `scripts/pptx-deploy.sh office-config` genera
   `configuration.xml` (Office Deployment Tool, strumento ufficiale Microsoft).
4. **Licenze legittime soltanto**. `auto` sceglie Office LTSC 2024 Volume se
   `OFFICE_KEY` è presente (con `AUTOACTIVATE`), altrimenti Microsoft 365 Apps
   per il trial via sign-in. **Nessun attivatore di pirateria (MAS/HWID)**: non
   viene implementato né documentato.
5. **CLI unica `scripts/pptx-deploy.sh`** per init/doctor/office-config/up/down/
   reset/logs/status/url, in bash, testata con bats e shellcheck.

## Alternative considerate

- **WinApps seamless da subito**: rinviata a Fase 2; richiede `winapps.conf`,
  `oem/RDPApps.reg` e fine-tuning RAIL. Il container sottostante è identico,
  quindi non è lavoro buttato.
- **Podman rootless**: scartato per ora su scelta dell'utente; docker è il
  backend raccomandato da dockur/WinApps ed evita permessi extra su `/dev/kvm`.
- **libvirt/QEMU diretto**: molta più automazione manuale, nessun vantaggio per
  l'obiettivo attuale.
- **Attivatore MAS**: scartato. Viola i termini di licenza Microsoft e non è
  automatizzabile in un progetto che dichiara fedeltà tramite software reale e
  legittimo.

## Conseguenze

- Positivo: un comando (`up`) e si ha Windows + Office; `reset --yes` rende
  l'ambiente disposable; i segreti stanno in un solo file locale.
- Positivo: la stessa VM alimenta il futuro seamless WinApps.
- Negativo: primo avvio lento (ISO + Office); nessun editing Office senza una
  key valida o sign-in al trial.
- Rischio: il link dell'ODT cambia nel tempo → `ODT_URL` è configurabile.

## Riferimenti

- dockur/windows: <https://github.com/dockur/windows> (README, `docs/environment.md`).
- ODT, opzioni di configurazione e product ID: <https://learn.microsoft.com/microsoft-365-apps/deploy/office-deployment-tool-configuration-options>.
- Download Center ODT (id=49117).
