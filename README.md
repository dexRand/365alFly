# pptx-open

Comando Linux-nativo per aprire `.pptx` con Microsoft PowerPoint **reale**
(non LibreOffice/OnlyOffice), con fedeltà di rendering identica a Windows,
in un ambiente disposable.

```

pptx-open ./presentazione.pptx

```

## Perché non Wine

Office 365 sotto Wine è storicamente instabile: si rompe a ogni
aggiornamento automatico del click-to-run, e le aree più critiche per la
fedeltà (SmartArt, animazioni, transizioni, font substitution) sono proprio
i punti deboli del layer di emulazione GDI/Direct2D/DirectWrite. Non esiste
un'immagine Docker "Wine + Office 365" pubblica e mantenuta, e per una
buona ragione: nessuno riesce a tenerla stabile nel tempo.

## Architettura scelta

Baseline: **WinApps** (https://github.com/winapps-org/winapps) — Windows
reale in un container Docker/Podman o VM libvirt, integrazione seamless
via FreeRDP. Fedeltà garantita perché è PowerPoint vero su Windows vero,
non emulazione.

Wine viene rivalutato solo *dopo* la baseline, come ottimizzazione
opzionale (vedi `AGENT_PLAN.md`, Fase 4) — non come strada principale.

## Struttura

```

/AGENT\_PLAN.md          — piano di lavoro per l'agente, fasi e gate
/docs/TEST\_MATRIX.md     — presentazioni di test e criteri di fedeltà
/docs/ACCEPTANCE.md      — criteri di accettazione finali
/winapps-baseline/       — setup e config della VM WinApps (popolato in Fase 1)
/wrapper/                — script pptx-open (popolato in Fase 2)
/wine-poc/               — eventuale tentativo Wine opzionale (Fase 4, solo se necessario)

```

## Stato

🚧 In fase di setup — nessun codice ancora, solo pianificazione.
