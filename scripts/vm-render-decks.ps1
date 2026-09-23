# pptx-open — esporta i deck di test in PNG 1600x900 usando PowerPoint reale.
# Gira DENTRO la VM Windows (non sul host), da PowerShell:
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File Z:\vm-render-decks.ps1
#
# I PNG finiscono in Z:\vm-export\<deck>\SlideN.PNG e vanno confrontati con i
# reference nativi in winapps-baseline/captures/native/ (SHA256 / RMSE).
# Vedi docs/TEST_MATRIX.md.
param(
  [string]$Src = "Z:\test_files",
  [string]$Out = "Z:\vm-export"
)

$ErrorActionPreference = "Stop"
if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Path $Out | Out-Null

$ppt = New-Object -ComObject PowerPoint.Application
foreach ($f in Get-ChildItem -Path $Src -Filter *.pptx | Sort-Object Name) {
  $dest = Join-Path $Out $f.BaseName
  New-Item -ItemType Directory -Path $dest -Force | Out-Null
  try {
    $pres = $ppt.Presentations.Open($f.FullName, $true, $false, $false)
    $pres.Export($dest, "PNG", 1600, 900)
    $pres.Close()
    Write-Output ("OK   " + $f.Name)
  } catch {
    Write-Output ("FAIL " + $f.Name + " : " + $_)
  }
}
$ppt.Quit()
"done" | Out-File (Join-Path (Split-Path $Out) "export.done")
