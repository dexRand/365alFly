# Matrice di test — file

Deck generati da `scripts/gen-test-decks.py` (OOXML via stdlib, nessuna
dipendenza). Sono la base del gate di fedeltà di Fase 1: per ogni file va
confrontato lo screenshot **WinApps** vs **PowerPoint nativo** (riferimento).

## Mappatura matrice → file (docs/TEST_MATRIX.md)

| # | Elemento | File | Note |
|---|----------|------|------|
| 1 | Font | `fonts.pptx` | Georgia/Impact/Comic Sans MS ecc. (non standard): verifica substitution |
| 2 | Caselle di testo | `textboxes.pptx` | wrap off/on, autofit, anchor top/bottom |
| 3 | SmartArt | *(da creare nativamente)* | Non esprimibile in DrawingML raw |
| 4 | Immagini | `image.pptx` | PNG + immagine con `alphaModFix` 40% |
| 5 | Trasparenza | `transparency.pptx` | rettangoli con alpha 100/50/25% e nero 30/60/90% |
| 6 | Grafici | *(da creare nativamente)* | Richiede part chart+styles |
| 7 | Tabelle | `tables.pptx` | 3×3, header fill, bordi |
| 8 | Gruppi | `groups.pptx` | 2 gruppi di forme |
| 9 | Z-order | `zorder.pptx` | stesso set in ordine inverso (red/green swap) |
| 10 | Animazioni | `animation.pptx` | entrance fade on click (spid 2) + control slide |
| 11 | Transizioni | `transitions.pptx` | fade (slide1→2), push left (slide2→3) |
| 12 | Media | *(da creare nativamente)* | — |

## Cosa genera lo script

- `shapes.pptx` — forme base: rect, roundRect, ellipse, diamond, triangle,
  rightArrow (elemento aggiuntivo alle righe della matrice).

## Da creare sul riferimento nativo (PowerPoint su Windows)

File che vanno generati manualmente/automaticamente nel PowerPoint **reale**
di riferimento (SmartArt, chart con dati reali e legenda, video/audio
incorporato). Vanno salvati in questa cartella e committati, così entrambi i
render sono confrontabili in modo deterministico.

## Validazione

`python3 scripts/gen-test-decks.py` rigenera tutti i deck;
`python3 scripts/validate-pptx.py winapps-baseline/test_files` verifica
zip + well-formed XML (non garantisce l'assenza di repair-phase in
PowerPoint: la verifica reale avviene a Fase 1 con la VM).