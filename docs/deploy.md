# deploy — Windows + PowerPoint in container (Task 4, percorso VNC/RDP)

Specifica e guida operativa dell'ambiente che apre PowerPoint reale su Linux
senza passare da Wine. Backend: [`dockur/windows`](https://github.com/dockur/windows)
(Windows in Docker, QEMU+KVM). È lo stesso backend raccomandato da WinApps, ma
esposto direttamente via VNC web/RDP: l'integrazione seamless WinApps (Fase 2)
si appoggerà a questa stessa VM.

## Obiettivo

Con un comando l'utente ottiene un Windows con **Microsoft PowerPoint reale**
installato, accessibile da browser (VNC) o client RDP, con credenziali e
licenze pilotate da un unico file `.env` locale.

## Comandi

```bash
scripts/pptx-deploy.sh init            # crea deploy/.env con password casuale
scripts/pptx-deploy.sh doctor          # verifica prerequisiti host
scripts/pptx-deploy.sh up              # prepara l'OEM e avvia la VM
scripts/pptx-deploy.sh url             # stampa gli indirizzi di accesso
scripts/pptx-deploy.sh status|logs     # stato / log del container
scripts/pptx-deploy.sh down            # ferma la VM (dati conservati)
scripts/pptx-deploy.sh reset --yes     # elimina tutto (ambiente disposable)
```

Al primo `up`: download ISO Windows (~4,7 GB per `11l`), installazione
automatica, poi `install.bat` scarica l'Office Deployment Tool e installa
Office (~2 GB). Tempo tipico: 30–60 minuti, una sola volta (poi sta nel volume).

## Prerequisiti host (Arch / CachyOS)

```bash
sudo pacman -S --needed docker qemu-full freerdp shellcheck bats
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"    # richiede un nuovo login
```

`/dev/kvm` deve esistere ed essere scrivibile (`ls -l /dev/kvm`). Su CachyOS è
`crw-rw-rw-`, quindi rootless-friendly. Verifica con `scripts/pptx-deploy.sh doctor`.

## Configurazione: solo `deploy/.env`

Tutto ciò che cambia spesso sta in `deploy/.env` (gitignored, `chmod 600`):

| Variabile | Scopo |
|---|---|
| `VM_USER` / `VM_PASSWORD` | account Windows, usate da VNC web e RDP |
| `WINDOWS_KEY` | product key Windows (opzionale) |
| `OFFICE_EDITION` | `auto` \| `ltsc2024` \| `ltsc2021` \| `2019` \| `o365` |
| `OFFICE_KEY` | product key Office (25 caratteri) |
| `OFFICE_LANGUAGE`, `OFFICE_EXCLUDE` | lingua e app Office da non installare |
| `ODT_URL` | URL dello strumento di deploy Office |
| `WINDOWS_VERSION`, `VM_RAM`, `VM_CPU`, `VM_DISK` | risorse VM |
| `BIND_ADDR`, `WEB_PORT`, `RDP_PORT`, `VNC_PORT` | rete (default loopback) |
| `WEB_PROTECT` | `Y` = login Basic su web UI; default `N` (solo loopback) |
| `SHARED_DIR` | cartella condivisa bidirezionale con la VM (`Z:\`), default `deploy/shared` |

Il template pubblico è `deploy/.env.example`. `deploy/compose.yaml` non
contiene segreti: legge tutto da `.env` via `--env-file`.

## Licenze (policy)

- **Windows**: non attivato per default (watermark tollerato in sviluppo). Con
  `WINDOWS_KEY` la key viene passata a dockur (`KEY`).
- **Office**: `OFFICE_EDITION=auto` sceglie `ltsc2024` (Volume) se `OFFICE_KEY`
  è impostata, altrimenti `o365` (Microsoft 365 Apps, attivabile via sign-in /
  trial). Senza key Office resta non attivato: apre e visualizza in sola
  lettura, **non** salva.
- **Non** viene usato alcun attivatore di pirateria (MAS o simili): eludere il
  licensing Microsoft non è automatizzato da questo progetto. La key va
  acquistata dall'utente; il codice si limita a passarla a strumenti ufficiali.

La `configuration.xml` generata (contiene la key) e `.env` non vanno mai
committati: sono in `.gitignore`.

## Provisioning OEM

`deploy/oem/` viene copiata da dockur in `C:\OEM` e `install.bat` viene
eseguito all'ultimo passo dell'installazione:

1. installa i font da `C:\OEM\fonts` (o `Z:\fonts`), necessari al gate Manrope;
2. se esiste `C:\OEM\office\configuration.xml`, scarica l'ODT e installa Office;
3. `configure-trust.bat` — `Z:\` trusted location di Office + Protected View
   off + `LowRiskFileTypes` (nessun warning ShellExecute sui `.bat`/`.cmd`
   eseguiti dalla condivisione, usati dal trigger del wrapper);
4. `configure-session.bat` — screen saver/sospensione off (il wrapper usa la
   tastiera: una sessione bloccata intercetterebbe i tasti);
5. `configure-office.bat` — spegne l'onboarding di primo avvio di Office;
6. `nagkiller.vbs` — copiato nella cartella Startup **e** registrato in
   `HKCU\...\CurrentVersion\Run`: chiude da solo la finestra
   **"Sign in to set up Office"** che Office non attivato mostra a ogni avvio.
   Non è attivazione né richiede account: è un auto-dismiss del prompt.
7. scrive `C:\OEM\provisioned.txt` come marcatore.

Durante tutto il provisioning `status-gui.ps1` mostra sul desktop una finestra
con **barra di avanzamento** (visibile via VNC) che legge `C:\OEM\status.txt`,
così l'installazione lunga non sembra bloccata.

Grazie a questo, un `docker compose down -v` seguito da `up` ricrea un ambiente
identico **senza** il popup di sign-in. **Verificato il 2026-09-23**: dopo un
`down -v` reale, aprendo PowerPoint senza alcun aiuto manuale il prompt non
compare (resta solo la striscia PRODUCT NOTICE).

`scripts/pptx-deploy.sh prepare` genera `configuration.xml` e copia i font da
`winapps-baseline/fonts/` prima di avviare la VM.

### Product ID / channel (fonti Microsoft)

Mapping usato da `office-config`, da
[config options ODT](https://learn.microsoft.com/microsoft-365-apps/deploy/office-deployment-tool-configuration-options):

| Edizione | Product ID | Channel | AUTOACTIVATE |
|---|---|---|---|
| Office LTSC 2024 ProPlus | `ProPlus2024Volume` | `PerpetualVL2024` | sì (con key) |
| Office LTSC 2021 ProPlus | `ProPlus2021Volume` | `PerpetualVL2021` | sì (con key) |
| Office 2019 ProPlus | `ProPlus2019Volume` | `PerpetualVL2019` | sì (con key) |
| Microsoft 365 Apps for enterprise | `O365ProPlusRetail` | `Current` | no (sign-in) |

Le variabili VM sono documentate in
[dockur/windows docs/environment.md](https://github.com/dockur/windows/blob/master/docs/environment.md).

## Note host

- **BTRFS**: dockur avvisa che un disco raw su btrfs può dare problemi al setup
  di Windows (CoW). Mitigazione (una volta, prima del primo avvio):
  ```bash
  sudo chattr +C "$(docker volume inspect -f '{{.Mountpoint}}' pptx-open_vmdata)"
  ```
  `chattr +C` su una directory fa ereditare `No_COW` ai file creati dopo, quindi
  il `data.img` non è soggetto a CoW. `scripts/pptx-deploy.sh doctor` avvisa se
  rileva btrfs.
- **Gruppo docker**: dopo `usermod -aG docker "$USER"` serve un nuovo login.
  In alternativa, nella sessione corrente: `newgrp docker`.

## Troubleshooting

- **Finestra console nera al primo avvio**: è `install.bat` che esegue
  l'Office Deployment Tool con `Display=None`, quindi non stampa nulla a video.
  Non è bloccato; verifica l'attività reale:
  ```bash
  docker stats --no-stream pptx-open-windows   # BlockIO/CPU in crescita
  du -m /var/lib/docker/volumes/pptx-open_vmdata/_data/data.img
  ```
  Office impiega ~10–20 min dopo il primo boot; a fine provisioning la console
  si chiude e nella VM compare `C:\OEM\provisioned.txt`.
- **Screenshot della VM senza browser** (utile da script/CI): il container ha
  `perl`, quindi si può usare il monitor QEMU:
  ```bash
  docker exec pptx-open-windows perl -MIO::Socket::UNIX -e \
    'my $s=IO::Socket::UNIX->new(Peer=>"/run/shm/monitor.sock") or die $!; print $s "screendump /run/shm/s.ppm\n"; sleep 1;'
  docker exec pptx-open-windows cat /dev/shm/s.ppm > /tmp/s.ppm
  magick /tmp/s.ppm /tmp/s.png
  ```
  Nota: `docker cp` non attraversa il tmpfs di `/dev/shm`; usare `cat` su stdout.
- **Licenza Office**: `o365` senza key resta in sola lettura finché non fai il
  sign-in/trial; per l'attivazione automatica usa una key Volume (`ltsc2024`).
  Nessun attivatore di pirateria è previsto né supportato (vedi sotto).
- **`.env`: mai commenti inline nei valori.** Una riga tipo
  `WINDOWS_VERSION=11l   # nota` fa arrivare a dockur `VERSION` con il commento
  incluso (`Invalid VERSION`): il commento va su una riga a parte. `init`
  rimuove gli inline, `doctor` avvisa, un test lo impedisce.
- **Popup "Sign in to set up Office"**: è il gate di licenza di Office non
  attivato, non si sopprime via registro. `deploy/oem/nagkiller.vbs` lo chiude
  da solo in ~1s; per questo un ambiente ricreato da zero non lo mostra.

## Accesso

```bash
scripts/pptx-deploy.sh up
scripts/pptx-deploy.sh url
# apri http://127.0.0.1:8006/ nel browser (utente/password da deploy/.env)
```

Nel desktop Windows apri PowerPoint e i file condivisi da `Z:\` (`Shared`).
Per RDP usare FreeRDP o qualunque client: `127.0.0.1:3389`.

## Cartella condivisa (`Z:\`)

`SHARED_DIR` (default `deploy/shared`, gitignorata) è montata nella VM come
`Z:\` e come cartella **"Shared"** sul desktop. È bidirezionale:

```
host: deploy/shared/mia.pptx   ->   VM: Z:\mia.pptx
VM salva Z:\mia2.pptx          ->   host: deploy/shared/mia2.pptx
```

`scripts/pptx-deploy.sh prepare` crea la cartella e vi copia i deck di test in
`deploy/shared/test_files/` (visibili come `Z:\test_files\`), così il gate di
fedeltà funziona senza toccare `winapps-baseline/`. Per usare i tuoi documenti,
cambia `SHARED_DIR` in `deploy/.env` (assoluta o relativa a `deploy/`).

## Struttura

```
deploy/
  compose.yaml                 — servizio dockur/windows (nessun segreto)
  .env.example                 — template pubblico di configurazione
  oem/
    install.bat                — provisioning post-install
    office/install-office.bat  — download ODT + install Office
scripts/pptx-deploy.sh         — CLI (init/doctor/office-config/up/...)
tests/deploy.bats              — test della CLI (docker sostituito da stub)
```

## Confini

- **Sempre**: passare da `scripts/pptx-deploy.sh`; tenere `.env` e
  `configuration.xml` fuori da git; verificare con `doctor` prima di `up`.
- **Chiedere prima**: cambiare porta/`BIND_ADDR` (esporre la VM in rete) — in
  quel caso abilitare `WEB_PROTECT=Y`; cambiare edizione Office; aggiornare
  l'immagine docker.
- **Mai**: committare segreti/chiavi; aggiungere attivatori di pirateria;
  montare `/dev/kvm` o dati host sensibili in più del necessario.

## Criteri di successo

- [x] `init` produce `.env` con password casuale e permessi 600.
- [x] `doctor` fallisce in modo chiaro se manca KVM o docker.
- [x] `office-config` genera una `configuration.xml` valida e coerente con
      `OFFICE_EDITION`/`OFFICE_KEY` (suite `tests/deploy.bats`: 25 test verdi,
      shellcheck pulito).
- [x] `up` porta a un desktop con PowerPoint avviabile — verificato il
      2026-09-23: Windows 11 LTSC installato, desktop e autologin utente `pptx`,
      PowerPoint avviato sulla VM.
- [x] Il gate di fedeltà (`docs/TEST_MATRIX.md`) passa sulla VM: 21/25 slide
      byte-identiche, 4 solo antialiasing (2026-09-23).

## Domande aperte

1. ~~Login della web UI~~ Risolto: dockur usa HTTP Basic con
   `USERNAME`/`PASSWORD` della VM. Default ora `WEB_PROTECT=N` (la UI resta
   comunque su `127.0.0.1`).
2. Tempo effettivo di download+install Office dentro `install.bat`: se supera i
   limiti di dockur, spostare l'install su un task al primo logon.
3. ~~Passaggio da VNC a RDP seamless (RAIL)~~ Risolto: il wrapper usa
   `xfreerdp3` in RemoteApp (modalità default) e il provisioning imposta la
   `TSAppAllowList` (`deploy/oem/configure-remoteapp.bat`). Vedi
   `docs/wrapper.md`.
