#Requires -Version 5.1
<#
  Generates the native-reference decks (SmartArt, charts, media) with the
  real PowerPoint via COM, and exports PNG renders of every test deck into
  winapps-baseline/captures/native/.
  This is the fidelity gate placebo: WinApps renders will be compared 1:1
  against these PNGs.
#>
param(
    [string]$RepoRoot = "\\wsl.localhost\Ubuntu\home\user\Progetti\365alFly"
)

$ErrorActionPreference = "Stop"
$testFiles = Join-Path $RepoRoot "winapps-baseline\test_files"
$outNative = Join-Path $RepoRoot "winapps-baseline\captures\native"
New-Item -ItemType Directory -Force -Path $outNative | Out-Null

$wavPath = Join-Path $env:TEMP "pptx-open-tone.wav"
if (-not (Test-Path $wavPath)) { New-Item -ItemType File -Path $wavPath | Out-Null }

# --- generate a 0.5s 440Hz sine WAV (16-bit mono, 22050 Hz) ---
function New-ToneWav([string]$Path, [int]$Hz = 440, [double]$Seconds = 0.5, [int]$SampleRate = 22050) {
    $samples = [int]($SampleRate * $Seconds)
    $dataSize = $samples * 2
    $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter($fs)
    [byte[]]$riff = [System.Text.Encoding]::ASCII.GetBytes("RIFF")
    $bw.Write($riff)
    $bw.Write([int]($dataSize + 36))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVEfmt "))
    $bw.Write([int]16); $bw.Write([int16]1); $bw.Write([int16]1)
    $bw.Write([int]$SampleRate); $bw.Write([int]($SampleRate * 2)); $bw.Write([int16]2); $bw.Write([int16]16)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("data")); $bw.Write([int]$dataSize)
    for ($i = 0; $i -lt $samples; $i++) {
        $v = [math]::Round([math]::Sin(2 * [math]::PI * $Hz * $i / $SampleRate) * 12000)
        $bw.Write([int16]$v)
    }
    $bw.Close(); $fs.Close()
}
New-ToneWav -Path $wavPath

$pp = New-Object -ComObject PowerPoint.Application
$pp.Visible = [int]1

try {
    function Export-Deck {
        param([string]$Path, [int]$Width = 1600, [int]$Height = 900)
        $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        $dir = Join-Path $outNative $name
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        try {
            $pres = $pp.Presentations.Open($Path, $false, $false, $true)
            $pres.Export($dir, "PNG", $Width, $Height)
            $nSlides = $pres.Slides.Count
            $pres.Close()
            Write-Output "  exported: $name ($nSlides slides) -> $dir"
        }
        catch {
            Write-Output "  FAILED to export: $name -- $($_.Exception.Message)"
        }
    }

    function New-SlideDeck {
        param([string]$Name, [scriptblock]$BuildSlide)
        $pres = $pp.Presentations.Add()
        $pres.Application.Visible = [int]1
        $slide = $pres.Slides.Add(1, 12)  # ppLayoutBlank = 12
        & $BuildSlide $slide
        $out = Join-Path $testFiles $Name
        $pres.SaveAs($out)
        $pres.Close()
        Write-Output "  saved deck: $Name"
    }

    # ---- smartart.pptx ----
New-SlideDeck -Name "smartart.pptx" -BuildSlide {
    param($slide)
    $layouts = $pp.SmartArtLayouts
    $layout = $layouts.Item(1)
    $null = $slide.Shapes.AddSmartArt($layout, 60, 60, 900, 450)
}

# ---- charts.pptx ----
New-SlideDeck -Name "charts.pptx" -BuildSlide {
    param($slide)
    # xlColumnClustered=51; default embedded data is enough for a render check
    $null = $slide.Shapes.AddChart2(201, 51, 60, 60, 900, 450)
}

# ---- media.pptx ----
New-SlideDeck -Name "media.pptx" -BuildSlide {
    param($slide)
    $audio = $slide.Shapes.AddMediaObject2($wavPath, $false, $true, 60, 60, 300, 60)
    $audio.Name = "TestTone"
}

# ---- animation.pptx (real fade entrance on click) ----
$animPres = $pp.Presentations.Add()
$animPres.Application.Visible = [int]1
$s1 = $animPres.Slides.Add(1, 12)  # ppLayoutBlank
$box = $s1.Shapes.AddTextbox(1, 60, 60, 700, 150)  # msoTextOrientationHorizontal
$box.TextFrame.TextRange.Text = "this box fades in on click"
$box.TextFrame.TextRange.Font.Size = 28
$box.Fill.ForeColor.RGB = 0x503E2C    # 2C3E50 (BGR)
$eff = $s1.TimeLine.MainSequence.AddEffect($box, 10)  # msoAnimEffectFade
$eff.Timing.TriggerType = 1  # msoAnimTriggerOnPageClick
$s2 = $animPres.Slides.Add(2, 12)
$box2 = $s2.Shapes.AddTextbox(1, 60, 60, 700, 150)
$box2.TextFrame.TextRange.Text = "plain box (control)"
$box2.TextFrame.TextRange.Font.Size = 28
$box2.Fill.ForeColor.RGB = 0x85A016    # 16A085 (BGR)
$animPres.SaveAs((Join-Path $testFiles "animation.pptx"))
$animPres.Close()
Write-Output "  saved deck: animation.pptx"

# ---- export native renders of ALL test decks ----
Write-Output "Exporting native reference renders..."
foreach ($pptx in Get-ChildItem -Path $testFiles -Filter *.pptx) {
    Export-Deck -Path $pptx.FullName
}
}
finally {
    $pp.Quit()
    Write-Output "DONE"
}