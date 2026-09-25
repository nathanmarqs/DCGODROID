param(
    [string]$ApkPath = "",
    [switch]$LaunchAfterInstall = $true
)

$ErrorActionPreference = 'Stop'
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path }

if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $ScriptDir "output\DCGO-android-latest.apk"
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Engine-Deploy] ADB Deployment & Synchronization" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Locate adb
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
    throw "ADB not found. Please verify Android SDK installation."
}

# 2. Check Connected Devices
Write-Host "  -> Checking for USB/ADB devices..." -ForegroundColor Yellow
$devicesRaw = & $adb devices -l
$devices = $devicesRaw | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of devices attached" }

if (!$devices) {
    Write-Host "  [Warning] No authorized Android device detected via USB." -ForegroundColor Red
    Write-Host "  Please connect your tablet/smartphone with 'USB Debugging' enabled and try again." -ForegroundColor Yellow
    return $false
}

Write-Host "  -> Connected device(s) found:" -ForegroundColor Green
$devices | ForEach-Object { Write-Host "     $_" -ForegroundColor Green }

# 3. Validate APK existence
if (!(Test-Path -LiteralPath $ApkPath)) {
    throw "APK file not found at: $ApkPath. Please run build first."
}

# 4. APK Installation
Write-Host "`n[1/3] Installing APK onto device..." -ForegroundColor Yellow
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$installOutput = & $adb install -r $ApkPath 2>&1 | Out-String
if ($installOutput -match "INSTALL_FAILED_UPDATE_INCOMPATIBLE" -or $installOutput -match "signatures do not match") {
    Write-Host "  -> Keystore signature difference detected. Reinstalling cleanly..." -ForegroundColor Yellow
    & $adb uninstall com.DCGO.DCGO 2>&1 | Out-Null
    $installOutput = & $adb install -r $ApkPath 2>&1 | Out-String
}
$ErrorActionPreference = $prevEAP
Write-Host "  -> $installOutput" -ForegroundColor $(if ($installOutput -match "Success") { "Green" } else { "Red" })

if ($installOutput -notmatch "Success") {
    throw "Failed to install APK via ADB: $installOutput"
}

# 5. Inject Starter Deck & Textures & Set Permissions
Write-Host "`n[2/3] Synchronizing Starter Decks & Battlefield Textures..." -ForegroundColor Yellow
$starterDeck = Join-Path $ScriptDir "patches\Decks\StarterDeck.txt"
if (Test-Path -LiteralPath $starterDeck) {
    & $adb shell "mkdir -p /sdcard/Android/data/com.DCGO.DCGO/files/Decks" | Out-Null
    & $adb push $starterDeck "/sdcard/Android/data/com.DCGO.DCGO/files/Decks/StarterDeck_01.txt" | Out-Null
    & $adb push $starterDeck "/sdcard/Android/data/com.DCGO.DCGO/files/Decks/UserDeck_01.txt" | Out-Null
    & $adb shell "chmod -R 777 /sdcard/Android/data/com.DCGO.DCGO/files/Decks" | Out-Null
    Write-Host "  -> Starter decks (StarterDeck_01 and UserDeck_01) synchronized with 777 permissions." -ForegroundColor Green
}

$texturesSrc = Join-Path $ScriptDir "patches\Assets-Locked\StreamingAssets\Textures"
if (Test-Path -LiteralPath $texturesSrc) {
    & $adb shell "mkdir -p /sdcard/Android/data/com.DCGO.DCGO/files/Textures" | Out-Null
    & $adb push "$texturesSrc\." "/sdcard/Android/data/com.DCGO.DCGO/files/Textures/" | Out-Null
    & $adb shell "date '+%Y-%m-%dT%H:%M:%S.0000000Z' > /sdcard/Android/data/com.DCGO.DCGO/files/Textures/.seeded_ui_v1" | Out-Null
    & $adb shell "chmod -R 777 /sdcard/Android/data/com.DCGO.DCGO/files/Textures" | Out-Null
    Write-Host "  -> Battlefield textures seeded directly to device with 777 permissions." -ForegroundColor Green
}

# 6. Launch Application
if ($LaunchAfterInstall) {
    Write-Host "`n[3/3] Launching DCGO on device..." -ForegroundColor Yellow
    & $adb shell input keyevent KEYCODE_WAKEUP | Out-Null
    & $adb shell wm dismiss-keyguard | Out-Null
    & $adb shell monkey -p com.DCGO.DCGO -c android.intent.category.LAUNCHER 1 | Out-Null
    Write-Host "  -> DCGO successfully launched on tablet!" -ForegroundColor Green
}

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host " [Engine-Deploy] Deployment Completed Successfully!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
return $true