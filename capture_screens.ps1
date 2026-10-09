# Captura de telas do Jalapao Monitor via ADB
# Monitora saida do flutter test e tira screenshot ao detectar [SCREEN_CAPTURE]
# v2.2: pasta renomeada para screenshots/YYYY-MM-DD/baseline (item 2.4)
#        referencia atualizada para baseline_operational_walkthrough.dart (item 2.1)
#        passo E2E de verificacao no PocketBase (item 2.5)

Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)

# ADB path
$env:PATH = "D:\DevTools\AndroidSDK\platform-tools;$env:PATH"

# 2.4: Pasta raiz com data
$dateStamp = Get-Date -Format 'yyyy-MM-dd'
$baseFolder = "screenshots\$dateStamp"

# Lista de testes para execução
$tests = @(
    @{ id = "baseline"; file = "integration_test/baseline_operational_walkthrough.dart" },
    @{ id = "peak_flow"; file = "integration_test/peak_flow_test.dart" },
    @{ id = "edge_cases"; file = "integration_test/edge_cases_test.dart" }
)

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

# PocketBase URL: argumento posicional ou env PB_URL (nunca literal no repo)
$PB_URL = if ($args[0]) { $args[0] } elseif ($env:PB_URL) { $env:PB_URL } else { "http://localhost:8090" }
Write-Host "PocketBase URL: $PB_URL" -ForegroundColor DarkCyan

foreach ($t in $tests) {
    $testId = $t.id
    $testFile = $t.file
    $currentFolder = "$baseFolder\$testId"
    
    Write-Host "`n=== Executando Teste: $testId ===" -ForegroundColor Yellow
    Write-Host "Arquivo: $testFile" -ForegroundColor Gray

    # Conta SINTETICA de teste do gestor via env (Issue #24 — sem credencial
    # embutida; o PIN local de fallback foi removido). Invocação direta com
    # array de argumentos: sem `cmd /c` para não reparsear valores com
    # &, |, ^, aspas ou espaços.
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
    # O pipeline não propaga o exit code do processo filho — verificar
    # explicitamente para não reportar verde com teste falho.
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FALHA: teste $testId encerrou com codigo $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Write-Host "`nFinalizado ciclo de testes. Screenshots em: $baseFolder" -ForegroundColor Cyan

# ── 2.5: Verificacao E2E no PocketBase (User Auth) ──────────────────────────
Write-Host "`n=== Verificando sync no PocketBase (E2E) ===" -ForegroundColor Yellow

# Credenciais de Gestor — lidas do ambiente (Issue #24 — sem literal no repo).
# Sem elas a verificação E2E cairia em acesso anônimo e reportaria verde falso:
# falha explícita antes de emitir qualquer query.
$PB_GESTOR_USER = $env:PB_GESTOR_USER
$PB_GESTOR_PASS = $env:PB_GESTOR_PASS
if (-not $PB_GESTOR_USER -or -not $PB_GESTOR_PASS) {
    Write-Error "Defina PB_GESTOR_USER e PB_GESTOR_PASS no ambiente para a verificacao E2E autenticada."
    exit 1
}

# Step 1: Autenticar para obter token
$authUrl  = "$PB_URL/api/collections/users/auth-with-password"
$authBody = @{ identity = $PB_GESTOR_USER; password = $PB_GESTOR_PASS } | ConvertTo-Json
$token    = $null

try {
    $authResp = Invoke-RestMethod -Uri $authUrl -Method Post -Body $authBody -ContentType 'application/json' -TimeoutSec 10
    $token = $authResp.token
    Write-Host "Gestor Auth OK. Token obtido." -ForegroundColor DarkGreen
} catch {
    Write-Error "Falha na autenticacao do Gestor: $_. E2E abortado — sem credencial valida nao ha verificacao autenticada (acesso anonimo reportaria verde falso)."
    exit 1
}
if (-not $token) {
    Write-Error "Autenticacao retornou sem token. E2E abortado."
    exit 1
}

# Step 2: Consultar place_visits com token
$headers = @{}
if ($token) { $headers["Authorization"] = "Bearer $token" }

# Collection confirmada: 'visits'
$pbEndpoint = "$PB_URL/api/collections/visits/records?sort=-created&perPage=5"
Write-Host "GET $pbEndpoint" -ForegroundColor DarkGray
try {
    $response = Invoke-RestMethod -Uri $pbEndpoint -Method Get -Headers $headers -TimeoutSec 10
    $count = $response.totalItems
    Write-Host "OK PocketBase (visits): $count registros totais" -ForegroundColor Green
    if ($response.items -and $response.items.Count -gt 0) {
        Write-Host "   Ultimos registros:" -ForegroundColor DarkGreen
        $response.items | ForEach-Object {
            Write-Host ("   - id={0} | created={1}" -f $_.id, $_.created) -ForegroundColor DarkGreen
        }
    } else {
        Write-Host "   AVISO: Nenhum registro ainda - tablet pode nao ter sincronizado." -ForegroundColor DarkYellow
    }
} catch {
    Write-Host "ERRO ao acessar 'visits': $_" -ForegroundColor Red
}

Write-Host "`n=== Fim da pipeline E2E ===" -ForegroundColor Cyan
