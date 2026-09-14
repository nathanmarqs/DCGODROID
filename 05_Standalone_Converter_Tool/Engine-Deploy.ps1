param(
    [string]$ApkPath = (Join-Path $PSScriptRoot "output\DCGO-android-latest.apk"),
    [switch]$LaunchAfterInstall = $true
)

$ErrorActionPreference = 'Stop'
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Engine-Deploy] Instalação e Sincronização ADB" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Localizar adb
$adbPaths = @(
    "C:\Program Files\Unity\Hub\Editor\2021.3.45f2\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\platform-tools\adb.exe",
    "C:\AndroidSDK\platform-tools\adb.exe",
    "adb.exe"
)

$adb = $null
foreach ($path in $adbPaths) {
    if (Test-Path -LiteralPath $path) {
        $adb = $path
        break
    }
}

if (!$adb) {
    throw "ADB não encontrado. Verifique o Android SDK."
}

# 2. Verificar Dispositivos Conectados
Write-Host "  -> Verificando dispositivos USB/ADB..." -ForegroundColor Yellow
$devicesRaw = & $adb devices -l
$devices = $devicesRaw | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of devices attached" }

if (!$devices) {
    Write-Host "  [Aviso] Nenhum dispositivo Android conectado ou autorizado via USB." -ForegroundColor Red
    Write-Host "  Conecte seu tablet/smartphone com 'Depuração USB' ativada e tente novamente." -ForegroundColor Yellow
    return $false
}

Write-Host "  -> Dispositivo encontrado:" -ForegroundColor Green
$devices | ForEach-Object { Write-Host "     $_" -ForegroundColor Green }

# 3. Validar existência do APK
if (!(Test-Path -LiteralPath $ApkPath)) {
    throw "APK não encontrado em: $ApkPath. Execute a compilação primeiro."
}

# 4. Instalação do APK
Write-Host "`n[1/3] Instalando APK no dispositivo..." -ForegroundColor Yellow
$installOutput = & $adb install -r $ApkPath
Write-Host "  -> $installOutput" -ForegroundColor $(if ($installOutput -match "Success") { "Green" } else { "Red" })

if ($installOutput -notmatch "Success") {
    throw "Falha ao instalar o APK via ADB: $installOutput"
}

# 5. Injetar Deck Inicial e Permissões
Write-Host "`n[2/3] Sincronizando Decks Iniciais..." -ForegroundColor Yellow
$starterDeck = Join-Path $PSScriptRoot "patches\Decks\StarterDeck.txt"
if (Test-Path -LiteralPath $starterDeck) {
    & $adb shell "mkdir -p /sdcard/Android/data/com.DCGO.DCGO/files/Decks" | Out-Null
    & $adb push $starterDeck "/sdcard/Android/data/com.DCGO.DCGO/files/Decks/StarterDeck_01.txt" | Out-Null
    & $adb shell "chmod 777 /sdcard/Android/data/com.DCGO.DCGO/files/Decks/StarterDeck_01.txt" | Out-Null
    Write-Host "  -> Deck inicial transferido com permissões 777." -ForegroundColor Green
}

# 6. Iniciar Aplicativo
if ($LaunchAfterInstall) {
    Write-Host "`n[3/3] Iniciando DCGO no dispositivo..." -ForegroundColor Yellow
    & $adb shell input keyevent KEYCODE_WAKEUP | Out-Null
    & $adb shell wm dismiss-keyguard | Out-Null
    & $adb shell monkey -p com.DCGO.DCGO -c android.intent.category.LAUNCHER 1 | Out-Null
    Write-Host "  -> DCGO iniciado com sucesso no tablet!" -ForegroundColor Green
}

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host " [Engine-Deploy] Concluído com Sucesso!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
return $true