# wrapper `pptx-open`

Apre un `.pptx` con Microsoft PowerPoint reale nella VM e, per default, attende
la chiusura sincronizzando il file salvato sull'host.

```bash
wrapper/pptx-open presentazione.pptx      # apre, attende, risincronizza
wrapper/pptx-open --no-wait deck.pptx     # apre e ritorna subito
wrapper/pptx-open --kill deck.pptx        # a fine sessione ferma la VM
wrapper/pptx-open --status                # stato VM + cartella condivisa
```

## Contratto CLI

| Opzione | Effetto |
|---|---|
| `--no-wait` | apre e ritorna senza attendere né sincronizzare |
| `--kill` | a fine sessione `docker compose down` (modalità disposable) |
| `--timeout SEC` | attesa massima della chiusura di PowerPoint (default 1800) |
| `--status` | stampa stato VM e percorso cartella condivisa |
| `-h`, `--help` | usage |

Exit code: `0` ok · `1` errore (file mancante, VM/helper, timeout) ·
`2` uso errato (nessun file).

## Meccanismo (VNC + cartella condivisa)

Niente RDP/RAIL: usa la stessa VM VNC della baseline.

1. copia il file in `<SHARED_DIR>/inbox/` e scrive `<SHARED_DIR>/request.txt`
2. copia l'helper `wrapper/vm/open-file.bat` in `<SHARED_DIR>/o.bat`
3. attiva `Z:\o.bat` nella VM via monitor QEMU (`sendkey`: Win+R → `Z:\o.bat`);
   l'helper apre PowerPoint con `start /wait` e, alla chiusura, scrive
   `Z:\done.txt`
4. il wrapper attende `done.txt` e risincronizza il file sull'host

L'helper (`wrapper/vm/open-file.bat`) fa: trova `POWERPNT.EXE`, chiude eventuali
istanze aperte, `start /wait "" POWERPNT.EXE Z:\<file>`, `echo ok> Z:\done.txt`.

## Requisiti

- VM attiva (il wrapper la avvia da solo con `docker compose up -d` e attende
  `Windows started successfully`).
- **Sessione Windows sbloccata**: il trigger usa la tastiera, quindi una
  sessione bloccata intercetta i tasti. `deploy/oem/configure-session.bat`
  (chiamato da `install.bat`) disattiva screen saver/sospensione; è applicato
  anche alla VM esistente.

## Test

`bats wrapper/tests/pptx-open.bats` — 8 test con docker/VM sostituiti da stub:
file mancante, usage, help, opzione sconosciuta, round-trip di sincronizzazione,
cleanup, errore segnalato dalla VM, `--status`.

## Limiti noti e follow-up

- **Seamless (RDP/RAIL)**: non usato. `xfreerdp3 /sec:rdp` autentica verso la VM,
  ma RemoteApp fallisce in post-connect perché serve disabilitare la
  `TSAppAllowList` (HKLM, elevazione). Follow-up possibile.
- **Trigger a tastiera**: dipende dal focus/desktop; robusto solo con sessione
  sbloccata (vedi sopra).
- **`--no-wait`** non sincronizza: il file resta in `inbox/`.
