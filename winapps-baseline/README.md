# winapps-baseline

Cartella della baseline WinApps (Fase 1/2).

## Dipendenza esterna: `winapps-org/winapps`

Il repo ufficiale è clonato qui in `winapps/` ma è **esterno al nostro
repo** (ignorato da git, vedi `.gitignore`). Non va vendered: è un
upstream da pinare e aggiornare.

- Repo: https://github.com/winapps-org/winapps
- Commit pin: `42c7e8318280c6fc3426c7afebfc7f43b895f4c8` (2026-09-14)
- Per eseguire il setup (con la VM Windows accesa):
  `bash <(curl https://raw.githubusercontent.com/winapps-org/winapps/main/setup.sh)`

Clone locale per leggere la doc ufficiale:
`git clone --depth 1 https://github.com/winapps-org/winapps.git winapps/`

## Contenuto attuale

- `winapps/` — clone upstream (gitignored)
- `test_files/` — 13 presentazioni di prova della matrice (9 OOXML raw +
  4 native: smartart, charts, media, animation)
- `captures/native/` — 25 PNG di riferimento (PowerPoint nativo su Windows
  host), committati; i render della VM sono disposable (gitignored)
- `fonts/Manrope-VariableFont.ttf` — font obbligatorio per il gate
  (aggiunto al deck `fonts.pptx`); va installato DENTRO la VM e sul native
- `compose.template.yaml` — template compose dockur **senza segreti**
  (credenziali reali solo in `~/.config/winapps/compose.yaml`, chmod 600)

## Config privata (mai committata)

- `~/.config/winapps/compose.yaml` — VM dockur con USERNAME/PASSWORD reali
- `~/.config/winapps/winapps.conf` — config WinApps (RDP_IP/PORT/USER/PASS)
- `~/.config/winapps/oem/` — copia di `winapps/`/oem per il post-install