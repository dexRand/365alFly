# e2e "explode" (Task 10) — helper DENTRO la VM.
#
# Apre il deck indicato in Z:\request.txt con PowerPoint REALE via COM,
# sostituisce il testo di una shape con un marker noto, salva e chiude.
# Il file sta su Z:\ (host), quindi il salvataggio arriva direttamente
# sull'host: e' un modo headless di simulare "apri -> modifica -> salva ->
# chiudi". Al termine scrive Z:\done.txt (ok / error:...).
param(
  [Parameter(Mandatory = $true)][string]$Rel
)

$ErrorActionPreference = "Stop"

function Write-Done([string]$Message) {
  Set-Content -Path "Z:\done.txt" -Value $Message -Encoding ascii
}

try {
  $path = "Z:\$Rel"
  $ppt = New-Object -ComObject PowerPoint.Application
  $pres = $ppt.Presentations.Open($path, $false, $false, $false)

  $edited = $false
  foreach ($shape in $pres.Slides.Item(1).Shapes) {
    if ($shape.HasTextFrame -and $shape.TextFrame.HasText) {
      $shape.TextFrame.TextRange.Text = "E2E-OK-365alFly"
      $edited = $true
      break
    }
  }
  if (-not $edited) { throw "nessuna shape con testo nella slide 1" }

  $pres.Save()
  $pres.Close()
  $ppt.Quit()
  Write-Done "ok"
}
catch {
  Write-Done ("error:" + $_.Exception.Message)
  exit 1
}
