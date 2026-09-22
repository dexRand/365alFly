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

## Contenuto previsto

- `winapps/` — clone upstream (gitignored)
- `test_files/` — presentazioni di prova della matrice (Task 3)
- `captures/` — screenshot WinApps vs nativi per il gate di fedeltà (Task 5/6)
- `oem/` — script post-install (es. install/attivazione Office) **senza segreti**