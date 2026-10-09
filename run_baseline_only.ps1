# Captura de telas do Jalapao Monitor via ADB (Apenas Baseline)
Set-Location "d:\antigravity_jalapao\jalapao_monitor\jalapao_monitor"
$env:PATH = "D:\DevTools\AndroidSDK\platform-tools;$env:PATH"

$dateStamp = Get-Date -Format 'yyyy-MM-dd'
$baseFolder = "screenshots\$dateStamp"
$testId = "baseline"
$testFile = "integration_test/baseline_operational_walkthrough.dart"
$currentFolder = "$baseFolder\$testId"

# Detecta device
$devLine = adb devices | Select-String "`tdevice$" | Select-Object -First 1
if (!$devLine) { Write-Error "Nenhum device Android encontrado."; exit 1 }
$dev = $devLine.ToString().Split("`t")[0].Trim()
Write-Host "Device: $dev" -ForegroundColor Cyan

function Snap($folder, $name) {
    if (!(Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
    $clean = $name -replace '[^a-zA-Z0-9_]', '_'
    $file  = "${clean}_$(Get-Date -Format 'HHmmss').png"
    Write-Host "   >>> Capturando: $file ..." -ForegroundColor Green
    adb -s $dev shell screencap -p /sdcard/sc.png
    adb -s $dev pull /sdcard/sc.png "$folder/$file"
}

$PB_URL = if ($env:PB_URL) { $env:PB_URL } else { "http://localhost:8090" }
Write-Host "PocketBase URL: $PB_URL" -ForegroundColor DarkCyan
Write-Host "Executando Teste: $testId" -ForegroundColor Yellow

# Secao do gestor usa conta SINTETICA de teste via env (Issue #24 — sem
# credencial embutida; o PIN local de fallback foi removido):
#   $env:TEST_GESTOR_EMAIL / $env:TEST_GESTOR_PASSWORD
# Invocação direta com array de argumentos: sem `cmd /c` para não reparsear
# credenciais com &, |, ^, aspas ou espaços.
$flutterArgs = @('test', $testFile, '-d', $dev, "--dart-define=PB_URL=$PB_URL")
if ($env:TEST_GESTOR_EMAIL -and $env:TEST_GESTOR_PASSWORD) {
    $flutterArgs += "--dart-define=TEST_GESTOR_EMAIL=$env:TEST_GESTOR_EMAIL"
    $flutterArgs += "--dart-define=TEST_GESTOR_PASSWORD=$env:TEST_GESTOR_PASSWORD"
}

& flutter @flutterArgs 2>&1 | ForEach-Object {
    Write-Host $_
    if ($_ -match '\[SCREEN_CAPTURE\]:\s*(.+)') {
        $n = $Matches[1].Trim()
        if ($n -notmatch '99_fim') { Snap $currentFolder $n }
    }
}
# O pipeline não propaga o exit code do processo filho — propagar explicitamente
# para não reportar verde com o walkthrough falho.
if ($LASTEXITCODE -ne 0) {
    Write-Host "FALHA: walkthrough encerrou com codigo $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}
