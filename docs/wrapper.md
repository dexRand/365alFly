# wrapper `pptx-open`

Apre un `.pptx` con Microsoft PowerPoint reale nella VM Windows.

Modo predefinito: **seamless** (RDP RemoteApp/RAIL) — PowerPoint appare come
finestra nativa sul desktop Linux e il file viene aperto **sul posto** tramite il
drive reindirizzato `\\tsclient\pptxopen`, quindi non serve copia/sync: quando
salvi, il file aggiornato è già quello sull'host.

```bash
wrapper/pptx-open presentazione.pptx      # seamless (default): finestra nativa
wrapper/pptx-open --desktop deck.pptx     # desktop Windows completo via RDP
wrapper/pptx-open --vnc deck.pptx         # desktop remoto VNC + sync cartella
wrapper/pptx-open --vnc --no-wait deck.pptx
wrapper/pptx-open --kill deck.pptx        # a fine sessione ferma la VM
wrapper/pptx-open --status                # stato VM + cartella condivisa
```

## Contratto CLI

| Opzione | Effetto |
|---|---|
| *(default)* | seamless RDP RemoteApp: apre il file dal drive reindirizzato |
| `--desktop` | desktop Windows completo via RDP (una sola finestra fluida) |
| `--vnc` | desktop remoto VNC; apre via helper e risincronizza il file salvato |
| `--no-wait` | *(solo `--vnc`)* apre e ritorna senza attendere né sincronizzare |
| `--kill` | a fine sessione `docker compose down` (modalità disposable) |
| `--timeout SEC` | *(solo `--vnc`)* attesa massima della chiusura (default 1800) |
| `--status` | stampa stato VM e percorso cartella condivisa |
| `-h`, `--help` | usage |

Exit code: `0` ok · `1` errore (file mancante, VM/FreeRDP/helper, timeout) ·
`2` uso errato (nessun file).

## Meccanismo

### default — seamless RDP RemoteApp (RAIL)

1. avvia la VM se non è attiva (`docker compose up -d`, attende
   `Windows started successfully` e poi che la porta RDP risponda: il marker
   di dockur appare quando parte QEMU, il desktop serve ~30 s in più);
2. lancia `xfreerdp3` con:
   - `/drive:pptxopen,<cartella del file>` — monta la cartella dell'host come
     drive remoto;
   - `/app:program:...POWERPNT.EXE,file:\\tsclient\pptxopen\<file>,name:PowerPoint`
     — chiede al server di avviare **solo** PowerPoint per quel file (RemoteApp);
   - `+clipboard /sound`, `/size:1280x800`.

PowerPoint scrive direttamente sul file host attraverso il drive: nessuna copia
di ritorno. Il comando resta bloccato finché la finestra remota non si chiude.

Perché RemoteApp sia concesso, il server deve elencare le app consentite:
`deploy/oem/configure-remoteapp.bat` (eseguito dal provisioning) imposta
`HKLM\...\RemoteApp\TSAppAllowList`.

### `--desktop` — desktop RDP completo

Stessa VM, ma `xfreerdp3` senza `/app`: si apre l'intero desktop Windows con
`/dynamic-resolution` e `--wm-class:MicrosoftPowerPoint`. Il file è comunque
raggiungibile dal drive `pptxopen`.

### `--vnc` — desktop remoto + cartella condivisa

Niente RDP: usa la stessa VM VNC della baseline e sincronizza via `SHARED_DIR`.

1. copia il file in `<SHARED_DIR>/inbox/` e scrive `<SHARED_DIR>/request.txt`;
2. copia l'helper `wrapper/vm/open-file.bat` in `<SHARED_DIR>/o.bat`;
3. attiva `Z:\o.bat` nella VM via monitor QEMU (`sendkey`: Win+R → `Z:\o.bat`);
   l'helper apre PowerPoint con `start /wait` e, alla chiusura, scrive
   `Z:\done.txt`. Il warning "Open File - Security Warning" che Windows mostra
   per i `.bat` della condivisione è soppresso da `LowRiskFileTypes`
   (`deploy/oem/configure-trust.bat`);
4. il wrapper attende `done.txt` e risincronizza il file sull'host.

L'helper (`wrapper/vm/open-file.bat`) fa: trova `POWERPNT.EXE`, chiude eventuali
istanze aperte, `start /wait "" POWERPNT.EXE Z:\<file>`, `echo ok> Z:\done.txt`.

## Configurazione

Percorsi e binari si possono sovrascrivere con variabili d'ambiente:
`PPTX_DEPLOY_DIR`, `PPTX_ENV_FILE`, `PPTX_COMPOSE_FILE`, `PPTX_CONTAINER`,
`PPTX_DOCKER_BIN`, `PPTX_FREERDP_BIN` (default `xfreerdp3`),
`PPTX_VM_HELPER_SRC` (helper `--vnc`; usato dai test e2e),
`PPTX_GUEST_READY_TIMEOUT` (attesa readiness del guest, default 180 s).

## Requisiti

- Docker + Compose (la VM viene avviata dal wrapper; il container si chiama
  `pptx-open-windows`).
- Client FreeRDP 3 (`xfreerdp3`; installabile con `freerdp` su Arch,
  `freerdp3-x11`/`freerdp2-x11` su Debian/Ubuntu).
- Per il trigger a tastiera della modalità `--vnc`, **sessione Windows
  sbloccata**: `deploy/oem/configure-session.bat` (chiamato da `install.bat`)
  disattiva screen saver/sospensione.

## Test

- `bats wrapper/tests/pptx-open.bats` — **9 test** con docker/VM sostituiti da
  stub: file mancante, usage, help, opzione sconosciuta, seamless (verifica di
  `/app:...POWERPNT.EXE`), desktop (nessun `/app`), round-trip `--vnc` con
  sincronizzazione, errore segnalato dalla VM, `--status`.
- `scripts/e2e-explode.sh` — test "explode" end-to-end su VM reale (richiede
  docker+VM): apre, **modifica**, salva, chiude e verifica che il file host sia
  cambiato. Vedi `tasks/todo.md` Task 10.

## Disposable e tempi di avvio

Decisione presa sui numeri (Task 7, 2026-09-24): **container disposable per
sessione, volume "golden" persistente**.

| Scenario | Tempo |
|---|---|
| Cold (ricrea tutto: ISO + Office, `down -v` + `up`) | ~22 min |
| Warm (container ricreato, Windows già nel volume) | ~37 s fino al desktop |

`pptx-open --kill` fa `docker compose down` (container rimosso, volume
conservato); il `reset` completo costa ~22 min ed è un'azione esplicita.

## Limiti noti e follow-up

- **`--vnc` con trigger a tastiera**: dipende dal focus/desktop; robusto solo
  con sessione sbloccata (vedi sopra).
- **`--no-wait`** non sincronizza: il file resta in `inbox/`.
- Il trigger a tastiera è intrinsecamente più fragile di RDP; per uso normale
  preferire la modalità seamless (default).
