# Ambiente host — Task 1 (Fase 0)

Data: 2026-09-22. Esegui `scripts/probe-env.sh` per riprodurre il probe su
qualunque host (WSL2 o Linux nativo).

## Vincolo di portabilità

Il target è **Linux in generale** (distribuzioni native), non solo questo
ambiente di sviluppo. Docker Desktop presente qui è **solo l'ambiente di
sviluppo**: la baseline WinApps e il wrapper `pptx-open` devono funzionare
su qualunque backend disponibile e su qualunque display:

- Backend: Docker **oppure** Podman **oppure** libvirt/QEMU (rilevamento
  automatico nel wrapper).
- Display: X11 **oppure** Wayland **oppure** WSLg.
- Nested virt: `/dev/kvm` richiesto (WSL2 e QEMU-in-container la danno via
  Hyper-V/WHQX). Dove manca, fallback documentato (libvirt su host fisico).

## Ambiente di sviluppo corrente

| Voce | Valore | Note |
|---|---|---|
| Host | Windows, kernel `5.15.153.1-microsoft-standard-WSL2` | WSL2 |
| Distro | Ubuntu 24.04.4 LTS (Noble) | `/etc/os-release` |
| CPU | 8 core, flag `vmx` presente | `nproc` |
| RAM | 13 GiB totali, ~4 GiB available | `free -h` — occhio concorrenza altri container |
| Disk | ~946 G liberi su `/` | `df -h` |
| KVM | `/dev/kvm` presente | WSL2 nested virt attiva (no `nestedVirtualization` esplicito nel `.wslconfig`) |
| Docker | 29.8.0 attivo (Docker Desktop, cgroup v1) | Daemon up, altri container in esecuzione (open-webui, llama-server) |
| Podman | assente | — |
| libvirt/QEMU | assente (virsh, qemu-system-x86_64 mancanti) | Fallback non disponibile qui |
| FreeRDP | assente (`xfreerdp`/`xfreerdp3` mancanti) | **Da installare** (`freerdp2-x11` in apt) |
| Display | WSLg attivo (DISPLAY=:0, WAYLAND_DISPLAY=wayland-0, `/mnt/wslg` montato) | GUI seamless OK senza X server esterno |
| Strumenti | present: wget, curl, git; mancanti: unzip, shellcheck, bats, cpu-checker | Installare i mancanti (tutti in apt) |

`.wslconfig` (Windows lato): `memory=14GB, processors=8, swap=4GB`.

## Requisiti vs stato

| Requisito WinApps/FreeRDP | Stato qui | Azione |
|---|---|---|
| `/dev/kvm` (nested virt) | ✅ presente | — |
| Engine container (Docker/Podman) | ✅ Docker | — |
| Client FreeRDP | ❌ assente | `sudo apt install freerdp2-x11` |
| Display X11/Wayland | ✅ WSLg | — |
| gold image / licenza Office | non ancora | Task 4 (Fase 1) |
| ISO Windows | non ancora | Task 2/4 |

## Blocchi documentati

1. **Basso**: FreeRDP client non installato — risolvibile con apt.
2. **Da verificare in Task 2**: requisiti ufficiali WinApps (quale backend
   raccomandato, dimensione immagine, RAM/disk minimi, procedura Office).
3. **Da verificare in Fase 1**: QEMU dentro container Docker in ambiente
   WSL2 (pass-through di `/dev/kvm`); se Docker Desktop non permette
   `--device /dev/kvm` con i privilegi giusti, usare il container con
   `--privileged` o switchare a libvirt.
4. **Memoria**: con la VM Windows (tipicamente 4-8 GiB) la RAM disponibile
   qui è al limite — monitorare; eventualmente ridurre RAM VM o chiudere
   container non usati.

## Requisiti WinApps — da fonte ufficiale (Task 2)

Fonte primaria: `winapps-baseline/winapps/README.md` +
`docs/docker.md` + `compose.yaml` (repo `winapps-org/winapps`, main).
Link: https://github.com/winapps-org/winapps .

### Fatti verificati dalla doc ufficiale

- **Backend**: Docker e Podman sono raccomandati ("facilitate an automated
  Windows installation process"); libvirt è supportato ma richiede più
  configurazione manuale. Tutti e tre usano l'hypervisor KVM.
  (README §Installation, docs/docker.md)
- **Vincolo platform**: il backend Docker/Podman richiede GNU/Linux (KVM);
  non gira su altri host. (docs/docker.md) — WSL2 qui è Linux (kernel 5.15)
  quindi tecnicamente idoneo, ma il target resta Linux nativo.
- **Windows**: versioni supportate ≥ Windows 10; per le app RDP servono
  edizioni **Pro/Enterprise/Server** — **Home NON sufficiente**.
  (docs/docker.md)
- **Risorse VM di default** (compose.yaml): immagine
  `ghcr.io/dockur/windows:latest`, `VERSION=11`, `RAM_SIZE=4G`,
  `CPU_CORES=4`, `DISK_SIZE=64G`. Da tarare sul nostro host (13 GiB RAM).
- **Porte**: `3389` RDP, `8006` web-VNC per il setup Windows.
- **Device richiesti**: `/dev/kvm` e `/dev/net/tun` — qui entrambi presenti.
- **Capabilities**: `NET_ADMIN`, `NET_RAW` (dockur).
- **File sharing**: compose monta `${HOME}:/shared` (→ `\\host.lan\Data`);
  FreeRDP `+home-drive` dà `/home` via `\\tsclient\home`. Con iptables
  (vedi rischio).
- **Dipendenze Ubuntu** (comando ufficiale README §Step 2):
  `sudo apt install -y curl dialog freerdp3-x11 git iproute2 libnotify-bin netcat-openbsd`
- **FreeRDP ≥ 3 richiesto**; su Ubuntu 24.04 `freerdp3-x11` = 3.31.0 nei
  repo ufficiali (verificato con `apt-cache policy`). ✅
- **Config**: `~/.config/winapps/winapps.conf` con `RDP_USER`/`RDP_PASS`/
  `WAFLAVOR`; file `chmod 600`; `RDP_ASKPASS` per non passare la password
  sulla riga di comando. Nota: FreeRDP ≥ 3.9 **impone** password.
- **Setup**: con VM accesa → `bash <(curl https://raw.githubusercontent.com/winapps-org/winapps/main/setup.sh)`
  (installa `winapps-setup`).
- **PowerPoint o365**: `C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE`
  (apps/powerpoint-o365/info).

### Checklist installazione qui

- [ ] `apt install freerdp3-x11 dialog libnotify-bin netcat-openbsd iproute2 curl git`
      (freerdp3 verifica ✅; serve sudo dell'utente)
- [ ] Installare strumenti dev: `shellcheck bats unzip cpu-checker`
- [ ] Config `~/.config/winapps/winapps.conf` (Template in README §Step 3)
- [ ] Office/ISO Windows + licenza valida (vedi blocco sotto)

### Blocchi / rischi nuovi emersi (Task 2)

1. **Moduli iptables non caricati in WSL2** (`lsmod` vuoto per ip_tables/
   iptable_nat). linux env: la doc richiede iptables per il file sharing
   host↔Windows. In WSL2 il meccanismo di mount di Docker Desktop è
   diverso: da verificare in Task 4; fallback: `\\tsclient\home` via
   `+home-drive` oppure copia file esplicita nel wrapper.
2. **Licenza Office**: il progetto ha bisogno di una licenza M365 o di
   key/ISO Office 2016/2019 valide dell'utente. Non c'è modo di
   automatizzarlo legalmente: resta un prerequisito umano. La *golden
   image* (con licenza attivata) non va mai committata.
3. **RDP utente completo**: `RDP_USER`/`RDP_PASS` devono essere un account
   Windows completo (no PIN). Dipende da come settiamo il setup dockur
   (USERNAME/PASSWORD del compose).

## Esito Task 1

- [x] `docs/environment.md` scritto con i blocchi documentati
- [x] `scripts/probe-env.sh` riproducibile (verificare su Linux nativo in CI)

## Esito Task 2

- [x] Repo ufficiale WinApps clonato in `winapps-baseline/winapps` e doc letta
- [x] Requisiti riportati con citazione (sezione sopra)
- [x] `freerdp3-x11` disponibile nei repo ufficiali Ubuntu 24.04 (3.31.0)