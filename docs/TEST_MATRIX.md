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

- [ ] Tutti i test superati senza differenze visibili
- [ ] Differenze minori riscontrate (elencare)
- [ ] Differenze bloccanti riscontrate (elencare — indagare qualità RDP prima di altro)
