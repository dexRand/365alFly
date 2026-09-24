# pptx-open

**English** · [Italiano](README.it.md)

> Open `.pptx` files with **real Microsoft PowerPoint** on Linux — the same
> engine, the same fonts, the same rendering as Windows — inside a disposable
> Windows VM. No Wine, no LibreOffice, no fidelity compromise.

![Platform](https://img.shields.io/badge/platform-Linux-1793d1?logo=linux&logoColor=white)
![Backend](https://img.shields.io/badge/backend-dockur%2Fwindows-2496ED?logo=docker&logoColor=white)
![Office](https://img.shields.io/badge/PowerPoint-real-D24726?logo=microsoftpowerpoint&logoColor=white)
![Tests](https://img.shields.io/badge/tests-45%20passing-2ea44f)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## Contents

- [Why real PowerPoint (and not Wine)](#why-real-powerpoint-and-not-wine)
- [How it works](#how-it-works)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Usage](#usage)
- [Configuration](#configuration)
- [Licensing & activation](#licensing--activation)
- [Fidelity gate](#fidelity-gate)
- [Project structure](#project-structure)
- [Status & roadmap](#status--roadmap)
- [Documentation](#documentation)
- [Inspired by & built with](#inspired-by--built-with)
- [License](#license)

## Why real PowerPoint (and not Wine)

Office under Wine is historically unstable: it breaks on every Click-to-Run
update, and the parts that matter most for fidelity — SmartArt, animations,
transitions, font substitution — are exactly the weak spots of the emulated
GDI/Direct2D/DirectWrite layer. There is no maintained public
"Wine + Office 365" image.

This project takes the boring, reliable route: **a real Windows VM, running
real Office**, kept in a container and driven from Linux. Rendering fidelity is
not emulated — it is inherited.

## How it works

`dockur/windows` runs Windows 11 LTSC in QEMU/KVM inside a Docker container.
Office is installed automatically with Microsoft's official Office Deployment
Tool (ODT). By default the wrapper launches PowerPoint as a **seamless**
window over RDP RemoteApp and opens the file in place through a redirected
drive, so saves land directly on the host. A full RDP desktop (`--desktop`) and
a web-VNC mode (`--vnc`, files exchanged through the shared folder `Z:\`) are
also available.

```mermaid
flowchart LR
  subgraph HOST["Linux host"]
    CLI["pptx-open CLI"]
    BR["Browser - noVNC :8006"]
    SH["deploy/shared - Z: (bidirectional)"]
  end
  subgraph CONT["Docker / dockur-windows / QEMU-KVM"]
    WIN["Windows 11 LTSC"]
    PP["Microsoft PowerPoint"]
  end
  CLI -- "docker compose" --> WIN
  CLI -- "RDP - seamless / desktop" --> WIN
  BR -- "VNC" --> WIN
  SH -- "files" --> WIN
  WIN --> PP
```

Everything is configured from a single local file, `deploy/.env`
(git-ignored): credentials, resources, network and licenses. No secrets are
ever committed.

## Requirements

- Linux with KVM (`/dev/kvm` present and writable)
- Docker (or Docker Desktop / Podman with KVM support) plus Compose
- FreeRDP 3 (`xfreerdp3`) for the seamless and desktop modes
- A display server: X11, or Wayland with XWayland. Without a local display,
  use the web-VNC mode from a browser
- ~8 GB RAM and ~40 GB free disk
- A Microsoft 365 trial **or** a product key for Office activation (see below)

`scripts/setup.sh` checks all of the above and installs only what is missing.

## Quick start

```bash
git clone https://github.com/dexRand/365alFly.git
cd 365alFly

# 1. host prerequisites: docker, docker compose, FreeRDP; verifies KVM
scripts/setup.sh                 # installs only what is missing (Arch/Debian/Fedora)
scripts/setup.sh --check         # report only, no changes
scripts/setup.sh --with-dev      # also install shellcheck + bats

# 2. bootstrap and start
scripts/pptx-deploy.sh init      # creates deploy/.env with a random password
scripts/pptx-deploy.sh up        # first run: ~30-60 min (downloads Windows + Office)
scripts/pptx-deploy.sh url       # open the printed URL in your browser
```

> `setup.sh` detects the distribution and skips packages that are already
> installed; it is safe to run it more than once.

The first `up` downloads the Windows ISO (~4.7 GB) and installs Office from
Microsoft's CDN (~2 GB). It is a one-time cost: the installed system lives in a
Docker volume and boots from disk afterwards.

## Usage

### GUI (web-VNC)

Open **<http://127.0.0.1:8006/>** — you get the Windows desktop. Launch
PowerPoint from the Start menu and work normally. The UI is bound to loopback
and needs no login by default (`WEB_PROTECT=N`).

### Command line

```bash
# once: put the wrapper on your PATH
ln -s "$PWD/wrapper/pptx-open" ~/.local/bin/pptx-open

pptx-open presentazione.pptx   # seamless PowerPoint window, file edited in place
pptx-open --desktop deck.pptx  # full Windows desktop over RDP
pptx-open --vnc deck.pptx      # web-VNC mode, syncs the saved file back
pptx-open --kill deck.pptx     # open, then stop the VM when done
pptx-open --status             # VM state + shared folder
```

### Exchanging files

Drop anything into `deploy/shared/` and it appears in Windows under **`Z:\`**
(and the **Shared** desktop folder). Changes made in Office are written back to
the same folder — it is bidirectional.

## Configuration

All settings live in `deploy/.env` (created by `init`, git-ignored, `chmod 600`).

| Variable | Purpose |
|---|---|
| `VM_USER` / `VM_PASSWORD` | Windows account, used by VNC and RDP |
| `WINDOWS_KEY` | Windows product key (optional) |
| `OFFICE_EDITION` | `auto` \| `ltsc2024` \| `ltsc2021` \| `2019` \| `o365` |
| `OFFICE_KEY` | Office product key (25 chars) |
| `OFFICE_LANGUAGE`, `OFFICE_EXCLUDE` | Office language / apps to skip |
| `WINDOWS_VERSION`, `VM_RAM`, `VM_CPU`, `VM_DISK` | VM resources |
| `BIND_ADDR`, `WEB_PORT`, `RDP_PORT`, `VNC_PORT`, `WEB_PROTECT` | networking |
| `SHARED_DIR` | folder shared with the VM (`Z:\`) |

Edit the file and re-run `scripts/pptx-deploy.sh up` to apply.

## Licensing & activation

This project **does not ship or automate any piracy tool** (no MAS, no KMS
emulator). Activation follows Microsoft's own mechanisms:

- **Product key** — put `OFFICE_KEY=xxxxx-xxxxx-xxxxx-xxxxx-xxxxx` in
  `deploy/.env`; `OFFICE_EDITION=auto` then installs **Office LTSC 2024
  (Volume)** and activates it automatically. No Microsoft account required.
- **Microsoft 365 trial** — with no key, `o365` is installed; sign in once in
  the VM to start the trial.
- **Unactivated** — Office still opens and renders `.pptx` files (read-only
  after the grace period), which is enough for the fidelity gate.

The unattended "Sign in to set up Office" prompt is auto-dismissed by a small
watcher (`deploy/oem/nagkiller.vbs`) so a fresh install drops you straight into
PowerPoint. That is UI convenience, **not** activation.

## Fidelity gate

A feature is **not** done when "PowerPoint opens" — it is done when the
rendering is indistinguishable from PowerPoint on Windows. The test suite
renders 13 tricky decks from the VM and compares them pixel-by-pixel against
native references:

> **21 / 25 slides byte-identical**; the remaining 4 differ only in text
> anti-aliasing (no layout, geometry or content differences).
> Verdict: [`docs/TEST_MATRIX.md`](docs/TEST_MATRIX.md).

## Project structure

```
deploy/                 compose + .env + OEM provisioning (dockur/windows)
scripts/setup.sh        host setup: checks and installs missing prerequisites
scripts/pptx-deploy.sh  environment CLI: init / doctor / office-config / up / down / reset
scripts/lib/            shared helpers (safe .env parser)
scripts/e2e-explode.sh  end-to-end "explode" test (open / edit / save / close)
wrapper/pptx-open       open a .pptx in real PowerPoint (seamless RDP / desktop / VNC)
wrapper/vm/             in-VM helper (open-file.bat)
tests/ + wrapper/tests/ bats test suites
winapps-baseline/       test decks, native reference PNGs, fonts
docs/                   deploy guide, wrapper guide, TEST_MATRIX, ADRs
```

## Status & roadmap

| Area | Status |
|---|---|
| Windows + Office environment (container, VNC/RDP) | working |
| Auto-provisioning (trusted folder, session, Office, prompt killer) | working |
| Fidelity gate (13 decks / 25 slides) | 21 byte-identical, 4 AA-only |
| `pptx-open` CLI wrapper | seamless RDP (default) + desktop + VNC, 45 tests green |
| Seamless RAIL integration (FreeRDP RemoteApp) | implemented (default mode) |
| End-to-end "explode" test (real VM) | `scripts/e2e-explode.sh` green |
| CI (shellcheck + bats) | workflow committed (`.github/workflows/ci.yml`) |
| Wine exploration | optional, not pursued |

## Documentation

- [`docs/deploy.md`](docs/deploy.md) — environment guide & configuration
- [`CHANGELOG.md`](CHANGELOG.md) — release history
- [`docs/wrapper.md`](docs/wrapper.md) — `pptx-open` CLI contract & mechanism
- [`docs/TEST_MATRIX.md`](docs/TEST_MATRIX.md) — fidelity matrix & verdict
- [`docs/adr/`](docs/adr) — architecture decisions
- [`docs/winapps-manual.md`](docs/winapps-manual.md) — historical WinApps/RAIL notes
- [`AGENT_PLAN.md`](AGENT_PLAN.md) · [`tasks/`](tasks) — roadmap and task tracking

## Inspired by & built with

This project stands on the shoulders of others. In rough order of importance:

| Project | What we took from it |
|---|---|
| [**dockur/windows**](https://github.com/dockur/windows) | The Windows-in-Docker container (QEMU/KVM) that is our backend, and the OEM/`install.bat` provisioning hook. |
| [**WinApps**](https://github.com/winapps-org/winapps) | The idea of running *real* Windows applications on Linux over FreeRDP; our phase-1 baseline and the seamless roadmap. |
| [**qemus/qemu**](https://github.com/qemus/qemu) | The QEMU-in-Docker layer that `dockur/windows` builds upon. |
| [**FreeRDP**](https://github.com/FreeRDP/FreeRDP) | The RDP client used for seamless RemoteApp integration and full-desktop access. |
| [**noVNC**](https://github.com/novnc/noVNC) | The web VNC viewer served on port 8006. |
| [**Microsoft Office Deployment Tool**](https://learn.microsoft.com/microsoft-365-apps/deploy/office-deployment-tool-configuration-options) | The official, supported way to install Office unattended. |

**Deliberately not used**, because they don't meet the fidelity bar: Wine,
LibreOffice, OnlyOffice. **Related projects** worth knowing if you want full
desktop integration: [WinBoat](https://winboat.app) and
[WinPodX](https://www.winpodx.org).

All product names, logos and trademarks are property of their respective
owners. This project is not affiliated with Microsoft.

## License

[MIT](LICENSE).
