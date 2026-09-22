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

## Esito Task 1

- [x] `docs/environment.md` scritto con i blocchi documentati
- [x] `scripts/probe-env.sh` riproducibile (verificare su Linux nativo in CI)