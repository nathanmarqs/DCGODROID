param(
    [string]$ApkPath = (Join-Path $PSScriptRoot "output\DCGO-android-latest.apk"),
    [switch]$LaunchAfterInstall = $true
)

$ErrorActionPreference = 'Stop'
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
$installOutput = & $adb install -r $ApkPath
Write-Host "  -> $installOutput" -ForegroundColor $(if ($installOutput -match "Success") { "Green" } else { "Red" })

if ($installOutput -notmatch "Success") {
    throw "Failed to install APK via ADB: $installOutput"
}

# 5. Inject Starter Deck & Set Permissions
Write-Host "`n[2/3] Synchronizing Starter Decks..." -ForegroundColor Yellow
$starterDeck = Join-Path $PSScriptRoot "patches\Decks\StarterDeck.txt"
if (Test-Path -LiteralPath $starterDeck) {
    & $adb shell "mkdir -p /sdcard/Android/data/com.DCGO.DCGO/files/Decks" | Out-Null
    & $adb push $starterDeck "/sdcard/Android/data/com.DCGO.DCGO/files/Decks/StarterDeck_01.txt" | Out-Null
    & $adb shell "chmod 777 /sdcard/Android/data/com.DCGO.DCGO/files/Decks/StarterDeck_01.txt" | Out-Null
    Write-Host "  -> Starter deck pushed with 777 permissions." -ForegroundColor Green
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