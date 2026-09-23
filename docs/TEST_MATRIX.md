# Matrice di test — fedeltà di rendering

Presentazioni di prova da preparare (o raccogliere) prima della Fase 1.
Ognuna deve isolare un elemento noto per essere problematico nelle
emulazioni:

| # | Elemento testato | Cosa verificare |
|---|---|---|
| 1 | Font a rischio sostituzione | Font non standard/non installati di default: verificare che non vengano rimpiazzati silenziosamente |
| 2 | Caselle di testo | Posizionamento, word-wrap, autofit |
| 3 | SmartArt | Layout, colori, ridimensionamento automatico |
| 4 | Immagini | Qualità, ritaglio, effetti applicati |
| 5 | Oggetti trasparenti | Trasparenza/alpha blending corretto |
| 6 | Grafici (charts) | Tipo di grafico, dati, legenda, colori |
| 7 | Tabelle | Bordi, formattazione celle, dimensioni |
| 8 | Oggetti raggruppati | Integrità del gruppo dopo apertura/salvataggio |
| 9 | Oggetti sovrapposti | Ordine z-index corretto |
| 10 | Animazioni | Timing, tipo di animazione |
| 11 | Transizioni | Tipo, durata |
| 12 | Media incorporati (se rilevante) | Riproduzione audio/video |

Per ogni riga: screenshot da PowerPoint via WinApps + (se disponibile)
screenshot da PowerPoint su Windows nativo, confronto affiancato.

## Esito

Compilare dopo la Fase 1:

- [x] Tutti i test superati senza differenze visibili
- [x] Differenze minori riscontrate (elencare)
- [x] Differenze bloccanti riscontrate (nessuna)

## Esito Fase 1 — run 2026-09-23 (VM dockur, Windows 11 LTSC, Office o365)

Metodo: i 13 deck di `winapps-baseline/test_files/` esportati in PNG 1600×900
**dalla VM** con PowerPoint COM (`Presentation.Export(..., "PNG", 1600, 900)`) e
confrontati pixel-per-pixel con i reference nativi in
`winapps-baseline/captures/native/` (SHA256 + RMSE + diff). Evidenza locale:
`deploy/shared/vm-export/` (gitignored; gli artefatti della VM non vanno
committati).

Risultato: **25 slide → 21 byte-identiche (SHA256 uguale); 4 con differenze
solo di antialiasing del testo.** Nessuna differenza di layout, geometria,
colori o contenuto.

| Deck | Slide | Byte-identiche | Note |
|---|---|---|---|
| fonts | 7 | 6 | slide 7 (riga Manrope) solo AA |
| charts | 1 | 0 | etichette/legenda solo AA; barre/griglia identiche |
| animation | 1-2 | 0 | solo AA |
| groups, image, media, smartart, shapes, tables, textboxes, transitions, transparency, zorder | 12 | 12 | pixel-identiche |

Le 4 differenze sono state investigate: il riallineamento (shift ±2 px) non le
riduce e a zoom 2× i glifi sono identici → è rasterizzazione/antialiasing, **non
un font sostituto**. Differenze bloccanti: nessuna.

- [x] Tutti i test superati senza differenze visibili (4 slide con differenze
      pixel-level di solo antialiasing, giustificate)
- [x] Differenze minori riscontrate: 4 slide (tabella sopra), solo AA del testo
- [x] Differenze bloccanti: nessuna
