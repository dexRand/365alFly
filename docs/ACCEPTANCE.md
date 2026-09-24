# Criteri di accettazione finale

Il progetto è considerato riuscito solo se **tutti** questi punti sono veri.
Esito verificato il 2026-09-24 (evidenze tra parentesi).

- [x] Lancia Microsoft PowerPoint reale, non un'alternativa
      (Office `o365` installato con l'ODT ufficiale; `POWERPNT.EXE` in
      `…\Microsoft Office\root\Office16\`).
- [x] Il `.pptx` si apre correttamente
      (apertura via wrapper seamless/RDP/VNC; e2e `scripts/e2e-explode.sh`).
- [x] La GUI di PowerPoint è visibile su Linux
      (finestra seamless via `xfreerdp3` RemoteApp, desktop RDP e web-VNC;
      screenshot raccolti durante i test).
- [x] Le presentazioni difficili di `TEST_MATRIX.md` rendono correttamente
      (21/25 slide byte-identiche; 4 differenze di solo antialiasing; nessuna
      differenza bloccante).
- [x] Font/layout accettabili
      (nessun font sostituito: le 4 differenze sono rasterizzazione, non
      sostituzione — vedi `docs/TEST_MATRIX.md`).
- [x] L'editing funziona
      (e2e: modifica del contenuto di una shape con PowerPoint reale via COM).
- [x] Il salvataggio funziona
      (e2e: SHA del file host cambiato e marker `E2E-OK-365alFly` presente
      dentro il `.pptx`).
- [x] La modalità presentazione/slide show funziona
      (verifica 2026-09-24: `SlideShowSettings.Run()` + navigazione + uscita,
      esito `ok`).
- [x] I file sopravvivono alla distruzione del container/VM disposable
      (e2e: `docker compose down`, container rimosso, file host intatto).
- [x] L'ambiente Office stesso può essere scartato e ricreato
      (`down -v` + `up` reale ~22 min il 2026-09-23; restart warm ~37 s).
- [x] Il backend usato è dichiarato esplicitamente: **Windows reale in
      container** (`dockur/windows`, QEMU/KVM) pilotato via **FreeRDP**
      (RemoteApp/RAIL e desktop RDP) e **VNC**; niente Wine/LibreOffice.
      Vedi `docs/wrapper.md`, `docs/deploy.md`, `README.md`.
- [x] Esplorazione Wine (Task 11): **non attivata** perché non si è presentato
      alcun blocco concreto in Fase 2; se fosse stata esplorata e non avesse
      superato il gate, sarebbe stata riportata esplicitamente.

Istruzione principale rispettata: l'obiettivo non era "PowerPoint si apre" ma
"la mia presentazione appare identica a come appare in PowerPoint su Windows".
