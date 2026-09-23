# WinApps manual baseline (historical / seamless reference)

Materiale storico della Fase 1: procedura manuale WinApps su WSL2/Ubuntu e nota
tecnica RDP. Il percorso attuale è il container automatizzato in `deploy/`
(vedi `docs/deploy.md`); questa pagina resta utile come riferimento per il
seamless (FreeRDP/RAIL) e per capire la scelta della VM.

## Nota tecnica RDP (2026-09-22)

La VM Win11 25H2 interrompe la connessione tra licenza e installazione
sessione: `BB_ERROR_BLOB` + `close notify`, identico con `mstsc` e
`xfreerdp3`. Individuato con FreeRDP `-multitransport` (supera la licenza, il
server chiude subito dopo il Demand Active). Riferimenti: FreeRDP issue #10864
(Win11/Server2025 + RDP TCP bug), KB5070311 (bug RemoteApp Dec-2025). Provate
senza esito varie combinazioni client (`-multitransport`, `-gfx`, `-rfx`,
`/bpp:16`): l'interruzione avviene lato server, identica con `mstsc`.
**Decisione (2026-09-22): base migrata a Windows 11 LTSC 2024 (`VERSION: "11l"`,
24H2/26100)** — build matura, iso 4.7 GB.

## Procedura manuale (WSL2/Ubuntu)

1. **Dipendenze host** (KVM, ~14 GB RAM, ~40 GB disco):

   ```bash
   sudo apt install -y docker.io xrdp xfreerdp3 shellcheck bats unzip aria2 cpu-checker
   sudo usermod -aG docker "$USER"
   sudo kvm-ok   # "KVM acceleration can be used"
   ```

2. **Config privata** (mai committata):

   ```bash
   mkdir -p ~/.config/winapps
   cp winapps-baseline/compose.template.yaml ~/.config/winapps/compose.yaml
   # impostare USERNAME/PASSWORD reali (chmod 600)
   ```

3. **OEM post-install** (`RDPApps.reg` per RemoteApp: disabilita l'allowlist):

   ```bash
   cp -r winapps-baseline/winapps/oem ~/.config/winapps/oem
   ```

4. **Config WinApps** (`~/.config/winapps/winapps.conf`, chmod 600):

   ```text
   WAFLAVOR="docker"
   RDP_IP="127.0.0.1"
   RDP_PORT="3389"
   RDP_USER="<USERNAME>"
   RDP_PASS="<PASSWORD>"
   CERT_PATH="/cert:tofu"
   RDP_FLAGS="/cert:tofu /sound /microphone +home-drive"
   ```

5. **Avvio VM e attesa installazione:**

   ```bash
   docker compose --file ~/.config/winapps/compose.yaml up -d
   docker logs -f WinApps   # attendere "Windows started successfully"
   ```

6. **Test RDP/RAIL (seamless):**

   ```bash
   xfreerdp3 /u:<USERNAME> /p:<PASSWORD> /v:127.0.0.1:3389 \
     /cert:tofu /app:program:notepad.exe /size:800x600 /timeout:20
   ```

I certificati RDP vanno in `~/.config/freerdp/` (tofu: cancellare
`server/127.0.0.1_3389.pem` dopo ogni cambio certificato VM).

## Nota sul RAIL (2026-09-23)

`xfreerdp3 /sec:rdp` autentica verso la VM, ma RemoteApp fallisce in
post-connect finché non si disabilita la `TSAppAllowList` (HKLM, elevazione).
Il wrapper attuale non usa RAIL: vedi `docs/wrapper.md`.
