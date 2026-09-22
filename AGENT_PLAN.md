# Piano per l'agente

Obiettivo: `pptx-open file.pptx` apre il file con Microsoft PowerPoint
reale, GUI visibile su Linux, con rendering indistinguibile da Windows,
in un ambiente disposable.

**Regola generale**: non dichiarare successo perché "PowerPoint si apre".
L'unico criterio valido è "la mia presentazione appare identica a come
appare in PowerPoint su Windows".

---

## Fase 0 — Intake

- Verificare che l'host supporti virtualizzazione annidata (`kvm-ok` o
  equivalente). È un prerequisito hard per WinApps.
- Clonare `winapps-org/winapps` (o il fork indicato) e leggere i
  requisiti di setup (Docker/Podman/libvirt, immagine Windows, licenza).
- Documentare qui eventuali blocchi hardware/software prima di procedere.

## Fase 1 — Baseline WinApps + gate di fedeltà

- Portare su la VM Windows + Office reale seguendo la procedura ufficiale
  WinApps.
- Eseguire i test descritti in `docs/TEST_MATRIX.md` su tutte le
  presentazioni di prova.
- Confrontare screenshot: PowerPoint via WinApps vs PowerPoint su Windows
  nativo (se disponibile un riferimento).

**Gate**: la fedeltà deve essere sostanzialmente identica, perché è
Office reale — non emulazione. Se qualcosa non torna, il problema è
quasi certamente di qualità/compressione RDP, non di rendering: indagare
in quella direzione (qualità FreeRDP, GPU, risoluzione) prima di mettere
in dubbio l'intero approccio.

## Fase 2 — Wrapper disposable `pptx-open`

- Script che:
  1. avvia/riusa la VM WinApps
  2. apre il file specifico via FreeRDP in modalità seamless (non
     desktop intero)
  3. aspetta la chiusura di PowerPoint
  4. verifica che il `.pptx` modificato sia sincronizzato sull'host
     (via `\\tsclient\home` o mount equivalente)
- Decisione da prendere con dati alla mano, non per principio: VM
  persistente in background (avvio più rapido, meno "disposable") vs
  VM che si spegne/rimuove dopo ogni sessione (vero disposable, ma con
  costo di boot misurabile). Misurare il tempo di boot reale e riportarlo
  prima di scegliere.
- Licenza/attivazione Office: va tenuta nella VM persistente ("immagine
  dorata"), mai nell'immagine Docker pubblica o versionata nel repo.

## Fase 3 — Test dell'"explode"

Sequenza di verifica end-to-end:

1. `pptx-open test.pptx`
2. modifica una slide
3. salva
4. chiudi PowerPoint
5. verifica che il `.pptx` modificato esista sull'host
6. verifica che il container/VM disposable sia stato rimosso (se questa
   è la modalità scelta in Fase 2)
7. rilancia `pptx-open test.pptx` e verifica un avvio pulito

Controllare che non restino container/VM morti accumulati.

## Fase 4 — Wine come ottimizzazione opzionale (non fallback primario)

Da esplorare **solo se** in Fase 2 emergono problemi concreti con
l'approccio WinApps (es. virtualizzazione annidata non disponibile sul
target, boot troppo lento per il caso d'uso). Time-box: poche ore, non
giorni. Aspettativa realistica: bassa probabilità di stabilità nel tempo,
perché Office 365 sotto Wine si rompe tipicamente a ogni aggiornamento
automatico — vedi note in `README.md`.

Se questa fase viene avviata, applicare lo stesso gate di fedeltà della
Fase 1 prima di considerare qualunque containerizzazione.

---

Vedi `docs/ACCEPTANCE.md` per i criteri finali di successo del progetto.
