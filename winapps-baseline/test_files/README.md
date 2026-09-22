# Matrice di test — file

Deck di base del gate di fedeltà di `docs/TEST_MATRIX.md`: per ogni file va
confrontato il render **WinApps** vs il render **PowerPoint nativo**
(riferimento, in `../captures/native/`).

## Origine dei deck

- `scripts/gen-test-decks.py` (OOXML via stdlib, nessuna dipendenza) →
  9 deck DrawingML-raw.
- `scripts/gen-native-decks.ps1` (PowerPoint reale via COM, solo su macchina
  con Office) → 4 deck non esprimibili in raw DrawingML:
  `smartart.pptx`, `charts.pptx`, `animation.pptx` (fade on click, reale),
  `media.pptx` (wav incorporato).

## Mappatura matrice → file

| # | Elemento | File | Note |
|---|----------|------|------|
| 1 | Font | `fonts.pptx` | Arial/Georgia/TNR/Courier/Impact/Comic Sans MS + **Manrope** (variabile). Manrope va installato su nativo Windows E nella VM: `../fonts/Manrope-VariableFont.ttf` (per-user nativo già fatto) |
| 2 | Caselle di testo | `textboxes.pptx` | wrap off/on, autofit, anchor top/bottom |
| 3 | SmartArt | `smartart.pptx` *(nativo)* | Layout #1 con `AddSmartArt` |
| 4 | Immagini | `image.pptx` | PNG + immagine con `alphaModFix` 40% |
| 5 | Trasparenza | `transparency.pptx` | rettangoli con alpha 100/50/25% e nero 30/60/90% |
| 6 | Grafici | `charts.pptx` *(nativo)* | Colonna clusterata, dati embedded di default (`AddChart2`) |
| 7 | Tabelle | `tables.pptx` | 3×3, header fill, bordi |
| 8 | Gruppi | `groups.pptx` | 2 gruppi di forme |
| 9 | Z-order | `zorder.pptx` | stesso set in ordine inverso (red/green swap) |
| 10 | Animazioni | `animation.pptx` *(nativo)* | entrance fade on click + control slide. Nota: un p:timing raw con animEffect viene rifiutato da PowerPoint con E_FAIL in apertura → generato con `AddEffect` |
| 11 | Transizioni | `transitions.pptx` | fade (slide1→2), push left (slide2→3) |
| 12 | Media | `media.pptx` *(nativo)* | wav 440Hz 0.5s incorporato con `AddMediaObject2` |

## Elementi extra

- `shapes.pptx` — forme base: rect, roundRect, ellipse, diamond, triangle,
  rightArrow.

## Capture di riferimento

Il primo run di `gen-native-decks.ps1` esporta ogni deck come PNG in
`../captures/native/<deck>/DiapositivaN.PNG` (nome localizzato, 1600×900).
Queste immagini sono la **baseline nativa** e vanno committate.

## Validazione

- `python3 scripts/validate-pptx.py winapps-baseline/test_files` — zip +
  well-formed XML.
- I deck raw venivano rifiutati da PowerPoint con E_FAIL finché le
  relationship slide→layout (`slideN.xml.rels`) non sono state aggiunte: è
  una regressione da tenere d'occhio quando si rigenera.
- L'apertura in PowerPoint reale (COM) senza E_FAIL è il segnale minimo;
  la verifica visuale avviene a Fase 1 (diff PNG).