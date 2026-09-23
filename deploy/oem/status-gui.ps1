# pptx-open — finestra di stato del provisioning, visibile via VNC.
# Legge C:\OEM\status.txt: ogni riga e' "PCT testo", dove PCT = -1 mostra una
# barra animata (indeterminata) e 0..100 una barra di avanzamento. Si chiude
# da sola ~8s dopo aver visto 100.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$statusFile = 'C:\OEM\status.txt'

$form = New-Object System.Windows.Forms.Form
$form.Text = 'pptx-open — provisioning'
$form.ClientSize = New-Object System.Drawing.Size(560, 150)
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true
$form.FormBorderStyle = 'FixedToolWindow'
$form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 27)
$form.ShowInTaskbar = $true

$label = New-Object System.Windows.Forms.Label
$label.Dock = 'Fill'
$label.ForeColor = [System.Drawing.Color]::White
$label.Font = New-Object System.Drawing.Font('Segoe UI', 12)
$label.TextAlign = 'MiddleCenter'
$label.Text = 'Avvio del provisioning...'

$bar = New-Object System.Windows.Forms.ProgressBar
$bar.Dock = 'Bottom'
$bar.Height = 28
$bar.Minimum = 0
$bar.Maximum = 100
$bar.Style = 'Marquee'

$form.Controls.Add($label)
$form.Controls.Add($bar)
$form.Show()

$doneSince = $null
while ($form.Visible) {
  [System.Windows.Forms.Application]::DoEvents()
  if (Test-Path -LiteralPath $statusFile) {
    $line = Get-Content -LiteralPath $statusFile -First 1 -ErrorAction SilentlyContinue
    if ($line -match '^(-?\d+)\s+(.*)$') {
      $pct = [int]$Matches[1]
      $label.Text = $Matches[2]
      if ($pct -lt 0) {
        $bar.Style = 'Marquee'
      } elseif ($pct -le 100) {
        $bar.Style = 'Blocks'
        $bar.Value = $pct
      }
      if ($pct -ge 100) {
        if (-not $doneSince) { $doneSince = Get-Date }
        if (((Get-Date) - $doneSince).TotalSeconds -gt 8) { $form.Close() }
      }
    }
  }
  Start-Sleep -Milliseconds 500
}
