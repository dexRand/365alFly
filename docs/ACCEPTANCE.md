# Criteri di accettazione finale

Il progetto è considerato riuscito solo se **tutti** questi punti sono
veri:

- [ ] Lancia Microsoft PowerPoint reale, non un'alternativa
- [ ] Il `.pptx` si apre correttamente
- [ ] La GUI di PowerPoint è visibile su Linux
- [ ] Le presentazioni difficili di `TEST_MATRIX.md` rendono correttamente
- [ ] Font/layout accettabili
- [ ] L'editing funziona
- [ ] Il salvataggio funziona
- [ ] La modalità presentazione/slide show funziona
- [ ] I file sopravvivono alla distruzione del container/VM disposable
- [ ] L'ambiente Office stesso può essere scartato e ricreato
- [ ] Il backend usato (WinApps/RDP, o eventualmente Wine) è dichiarato
      esplicitamente nel report finale — non lasciato implicito
- [ ] Se è stata esplorata la via Wine (Fase 4) e non ha superato il gate
      di fedeltà, questo va riportato chiaramente, non nascosto dietro un
      "funziona nella maggior parte dei casi"

Istruzione principale per l'agente: non ottimizzare per "PowerPoint si
apre". Ottimizzare per "la mia presentazione appare identica a come
appare in PowerPoint su Windows".
