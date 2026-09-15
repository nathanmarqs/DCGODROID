<#
.SYNOPSIS
    DCGO-Converter Orchestrator - Converts any DCGO version into a functional Android APK
.DESCRIPTION
    Interactive menu and orchestrator to clone, apply patches (Mali GPU shaders, dual-landscape orientation,
    resilient deck loading, IL2CPP ARM64) and compile ready-to-play Android APKs.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("git", "local", "deploy", "check")]
    [string]$Mode,

    [Parameter(Mandatory = $false)]
    [string]$TargetFolder,

    [Parameter(Mandatory = $false)]
    [string]$GitUrl = "https://github.com/DCGO2/DCGO.git",

    [Parameter(Mandatory = $false)]
    [string]$GitBranch = "master"
)

$Host.UI.RawUI.WindowTitle = "DCGO Android Converter & Builder"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Header {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "             DCGO ANDROID CONVERTER & BUILDER               " -ForegroundColor Yellow -BackgroundColor DarkBlue
    Write-Host "   Automated Pipeline: Clone -> Mali/Deck Patches -> APK    " -ForegroundColor Gray
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Environment {
    Write-Host "`n--- [4] Environment Diagnostics ---" -ForegroundColor Yellow
    
    # 1. Unity
    $unityPaths = @(
        "C:\Program Files\Unity\Hub\Editor\2021.3.45f2\Editor\Unity.exe",
        "C:\Program Files\Unity\Hub\Editor\2021.3.*\Editor\Unity.exe",
        "C:\Program Files\Unity\Editor\Unity.exe"
    )
    $unityExe = $null
    foreach ($p in $unityPaths) {
        $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $unityExe = $found.FullName; break }
    }

    if ($unityExe) {
        Write-Host "  [OK] Unity Editor: $unityExe" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Unity Editor 2021.3.x not found in C:\Program Files\Unity" -ForegroundColor Red
    }

    # 2. Android Build Support
    $unityDir = if ($unityExe) { Split-Path -Parent $unityExe } else { $null }
    $androidPlayer = if ($unityDir) { Join-Path $unityDir "Data\PlaybackEngines\AndroidPlayer" } else { $null }
    if ($androidPlayer -and (Test-Path $androidPlayer)) {
        Write-Host "  [OK] Unity Android Build Support installed: $androidPlayer" -ForegroundColor Green
    } else {
        Write-Host "  [WARNING] PlaybackEngines\AndroidPlayer not found in Unity." -ForegroundColor Yellow
    }

    # 3. Git
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $gitVer = & git --version
        Write-Host "  [OK] Git detected: $gitVer" -ForegroundColor Green
    } else {
        Write-Host "  [WARNING] Git not found in Windows PATH." -ForegroundColor Yellow
    }

    # 4. ADB
    $adbPaths = @(
        "adb.exe",
        "$androidPlayer\SDK\platform-tools\adb.exe",
        "C:\Program Files\Unity\Hub\Editor\2021.3.45f2\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\platform-tools\adb.exe",
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    )
    $adbExe = $null
    foreach ($a in $adbPaths) {
        $found = Get-Command $a -ErrorAction SilentlyContinue
        if ($found) { $adbExe = $found.Source; break }
        if (Test-Path $a) { $adbExe = $a; break }
    }

    if ($adbExe) {
        Write-Host "  [OK] ADB detected: $adbExe" -ForegroundColor Green
        # Check connected devices
        $devices = & $adbExe devices -l | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of devices attached" }
        if ($devices) {
            Write-Host "  [OK] Connected Android device(s):" -ForegroundColor Green
            $devices | ForEach-Object { Write-Host "       - $_" -ForegroundColor Cyan }
        } else {
            Write-Host "  [INFO] No USB debugging Android device detected right now." -ForegroundColor Gray
        }
    } else {
        Write-Host "  [WARNING] ADB not found. Automatic USB installation will not work." -ForegroundColor Yellow
    }

    Write-Host "`nDiagnostics completed." -ForegroundColor Yellow
}

function Invoke-GitConversion {
    param(
        [string]$RepoUrl,
        [string]$Branch
    )

    Write-Host "`n--- [1] Convert Version Directly from GitHub ---" -ForegroundColor Yellow
    if (-not $RepoUrl) {
        $RepoUrl = Read-Host "GitHub repository URL [default: https://github.com/DCGO2/DCGO.git]"
        if (-not $RepoUrl) { $RepoUrl = "https://github.com/DCGO2/DCGO.git" }
    }

    if (-not $Branch) {
        $Branch = Read-Host "Branch or Tag [default: master]"
        if (-not $Branch) { $Branch = "master" }
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $workspaceDir = Join-Path $ScriptDir "workspaces\DCGO_$timestamp"
    if (-not (Test-Path (Split-Path $workspaceDir))) {
        New-Item -ItemType Directory -Path (Split-Path $workspaceDir) -Force | Out-Null
    }

    Write-Host "`n[Step 1/4] Cloning $RepoUrl ($Branch) into $workspaceDir..." -ForegroundColor Cyan
    & git clone --depth 1 --branch $Branch $RepoUrl $workspaceDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[ERROR] Failed to clone git repository. Exit code: $LASTEXITCODE" -ForegroundColor Red
        return
    }

    Invoke-PatchAndBuild -ProjectDir $workspaceDir
}

function Invoke-LocalConversion {
    param([string]$ProjectDir)

    Write-Host "`n--- [2] Convert Local DCGO Project Folder ---" -ForegroundColor Yellow
    if (-not $ProjectDir) {
        $defaultLocal = "C:\Users\Administrator\Desktop\dcgo android\PROD\DCGO"
        Write-Host "Press ENTER to use: $defaultLocal" -ForegroundColor Gray
        $inputPath = Read-Host "Path to local DCGO project folder"
        $ProjectDir = if ($inputPath) { $inputPath.Trim('"') } else { $defaultLocal }
    }

    if (-not (Test-Path (Join-Path $ProjectDir "Assets"))) {
        Write-Host "[ERROR] Invalid directory! 'Assets' subfolder not found in: $ProjectDir" -ForegroundColor Red
        return
    }

    Invoke-PatchAndBuild -ProjectDir $ProjectDir
}

function Invoke-PatchAndBuild {
    param([string]$ProjectDir)

    # Step 1: Patches
    Write-Host "`n[Step 2/4] Applying Essential Patches (Mali Shaders, Dual Rotation, Decks)..." -ForegroundColor Cyan
    $patchScript = Join-Path $ScriptDir "Engine-Patch.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $patchScript -TargetProject $ProjectDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Patch application failed." -ForegroundColor Red
        return
    }

    # Step 2: Build
    Write-Host "`n[Step 3/4] Launching Headless Unity Batchmode Build..." -ForegroundColor Cyan
    $buildScript = Join-Path $ScriptDir "Engine-Build.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $buildScript -ProjectPath $ProjectDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Unity APK build failed." -ForegroundColor Red
        return
    }

    # Step 3: Deploy Prompt
    $latestApk = Join-Path $ScriptDir "output\DCGO-android-latest.apk"
    if (Test-Path $latestApk) {
        Write-Host "`n============================================================" -ForegroundColor Green
        Write-Host "   BUILD SUCCEEDED! APK GENERATED IN OUTPUT FOLDER          " -ForegroundColor Green
        Write-Host "============================================================" -ForegroundColor Green
        
        $choice = Read-Host "`nWould you like to install the APK and sync Starter Deck to your tablet now via USB? (Y/N) [default: Y]"
        if (-not $choice -or $choice -match "^[YySs]") {
            Invoke-DeployAction -ApkFile $latestApk
        }
    }
}

function Invoke-DeployAction {
    param([string]$ApkFile)

    Write-Host "`n--- [3] Android Device Installation (ADB) ---" -ForegroundColor Yellow
    if (-not $ApkFile) {
        $defaultApk = Join-Path $ScriptDir "output\DCGO-android-latest.apk"
        if (Test-Path $defaultApk) {
            $ApkFile = $defaultApk
        } else {
            $ApkFile = Read-Host "Enter path to .apk file to install"
            $ApkFile = $ApkFile.Trim('"')
        }
    }

    if (-not (Test-Path $ApkFile)) {
        Write-Host "[ERROR] APK file not found: $ApkFile" -ForegroundColor Red
        return
    }

    $deployScript = Join-Path $ScriptDir "Engine-Deploy.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $deployScript -ApkPath $ApkFile
}

# --- Parameterized Mode (CLI invocation) ---
if ($Mode) {
    switch ($Mode) {
        "git"    { Invoke-GitConversion -RepoUrl $GitUrl -Branch $GitBranch }
        "local"  { Invoke-LocalConversion -ProjectDir $TargetFolder }
        "deploy" { Invoke-DeployAction -ApkFile $TargetFolder }
        "check"  { Test-Environment }
    }
    exit 0
}

# --- Interactive Mode (Main Menu) ---
do {
    Write-Header
    Write-Host " Please select an option:" -ForegroundColor White
    Write-Host "  [1] Convert Directly from GitHub (Clone + Patch + Build)" -ForegroundColor Green
    Write-Host "  [2] Convert Local DCGO Project Folder (Patch + Build)" -ForegroundColor Cyan
    Write-Host "  [3] Install Latest APK + Starter Deck to Tablet (ADB USB)" -ForegroundColor Magenta
    Write-Host "  [4] Check Environment and Connected Devices" -ForegroundColor Yellow
    Write-Host "  [0] Exit" -ForegroundColor Gray
    Write-Host ""
    $opt = Read-Host "Option"

    switch ($opt) {
        "1" {
            Invoke-GitConversion
            Write-Host "`nPress any key to return to menu..." -ForegroundColor Gray
            [void][System.Console]::ReadKey($true)
        }
        "2" {
            Invoke-LocalConversion
            Write-Host "`nPress any key to return to menu..." -ForegroundColor Gray
            [void][System.Console]::ReadKey($true)
        }
        "3" {
            Invoke-DeployAction
            Write-Host "`nPress any key to return to menu..." -ForegroundColor Gray
            [void][System.Console]::ReadKey($true)
        }
        "4" {
            Test-Environment
            Write-Host "`nPress any key to return to menu..." -ForegroundColor Gray
            [void][System.Console]::ReadKey($true)
        }
        "0" {
            Write-Host "`nExiting DCGO Converter. See you next time!`n" -ForegroundColor Cyan
            break
        }
        default {
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($opt -ne "0")
