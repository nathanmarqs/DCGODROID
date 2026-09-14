<#
.SYNOPSIS
    DCGO-Converter Orchestrator - Converte qualquer versão do DCGO em APK Android funcional
.DESCRIPTION
    Menu interativo e orquestrador para clonar, aplicar patches (Mali GPU shaders, orientação dual-landscape,
    correção de decks, IL2CPP ARM64) e compilar APKs prontos para Android.
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
    Write-Host "   Automacao completa: Clone -> Patches Mali/Deck -> APK    " -ForegroundColor Gray
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Environment {
    Write-Host "`n--- [4] Verificacao de Ambiente ---" -ForegroundColor Yellow
    
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
        Write-Host "  [ERRO] Unity Editor 2021.3.x nao encontrado em C:\Program Files\Unity" -ForegroundColor Red
    }

    # 2. Android Build Support
    $unityDir = if ($unityExe) { Split-Path -Parent $unityExe } else { $null }
    $androidPlayer = if ($unityDir) { Join-Path $unityDir "Data\PlaybackEngines\AndroidPlayer" } else { $null }
    if ($androidPlayer -and (Test-Path $androidPlayer)) {
        Write-Host "  [OK] Unity Android Build Support instalado: $androidPlayer" -ForegroundColor Green
    } else {
        Write-Host "  [AVISO] PlaybackEngines\AndroidPlayer nao localizado no Unity." -ForegroundColor Yellow
    }

    # 3. Git
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $gitVer = & git --version
        Write-Host "  [OK] Git detectado: $gitVer" -ForegroundColor Green
    } else {
        Write-Host "  [AVISO] Git nao encontrado no PATH do Windows." -ForegroundColor Yellow
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
        Write-Host "  [OK] ADB detectado: $adbExe" -ForegroundColor Green
        # Check connected devices
        $devices = & $adbExe devices -l | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of devices attached" }
        if ($devices) {
            Write-Host "  [OK] Dispositivo(s) Android conectado(s):" -ForegroundColor Green
            $devices | ForEach-Object { Write-Host "       - $_" -ForegroundColor Cyan }
        } else {
            Write-Host "  [INFO] Nenhum aparelho Android com Depuracao USB detectado agora." -ForegroundColor Gray
        }
    } else {
        Write-Host "  [AVISO] ADB nao encontrado. A instalacao automatica via USB nao funcionara." -ForegroundColor Yellow
    }

    Write-Host "`nVerificacao concluida." -ForegroundColor Yellow
}

function Invoke-GitConversion {
    param(
        [string]$RepoUrl,
        [string]$Branch
    )

    Write-Host "`n--- [1] Converter Versao do GitHub ---" -ForegroundColor Yellow
    if (-not $RepoUrl) {
        $RepoUrl = Read-Host "URL do repositorio GitHub [padrao: https://github.com/DCGO2/DCGO.git]"
        if (-not $RepoUrl) { $RepoUrl = "https://github.com/DCGO2/DCGO.git" }
    }

    if (-not $Branch) {
        $Branch = Read-Host "Branch ou Tag [padrao: master]"
        if (-not $Branch) { $Branch = "master" }
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $workspaceDir = Join-Path $ScriptDir "workspaces\DCGO_$timestamp"
    if (-not (Test-Path (Split-Path $workspaceDir))) {
        New-Item -ItemType Directory -Path (Split-Path $workspaceDir) -Force | Out-Null
    }

    Write-Host "`n[Passo 1/4] Clonando $RepoUrl ($Branch) para $workspaceDir..." -ForegroundColor Cyan
    & git clone --depth 1 --branch $Branch $RepoUrl $workspaceDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[ERRO] Falha ao clonar repositorio git. Codigo de saida: $LASTEXITCODE" -ForegroundColor Red
        return
    }

    Invoke-PatchAndBuild -ProjectDir $workspaceDir
}

function Invoke-LocalConversion {
    param([string]$ProjectDir)

    Write-Host "`n--- [2] Converter Pasta Local do DCGO ---" -ForegroundColor Yellow
    if (-not $ProjectDir) {
        $defaultLocal = "C:\Users\Administrator\Desktop\dcgo android\PROD\DCGO"
        Write-Host "Pressione ENTER para usar: $defaultLocal" -ForegroundColor Gray
        $inputPath = Read-Host "Caminho da pasta do projeto DCGO"
        $ProjectDir = if ($inputPath) { $inputPath.Trim('"') } else { $defaultLocal }
    }

    if (-not (Test-Path (Join-Path $ProjectDir "Assets"))) {
        Write-Host "[ERRO] Pasta invalida! Nao foi encontrada a subpasta 'Assets' em: $ProjectDir" -ForegroundColor Red
        return
    }

    Invoke-PatchAndBuild -ProjectDir $ProjectDir
}

function Invoke-PatchAndBuild {
    param([string]$ProjectDir)

    # Passo 1: Patches
    Write-Host "`n[Passo 2/4] Aplicando Patches Essenciais (Shaders Mali, Rotacao Dual, Decks)..." -ForegroundColor Cyan
    $patchScript = Join-Path $ScriptDir "Engine-Patch.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $patchScript -TargetProject $ProjectDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERRO] Falha na etapa de patches." -ForegroundColor Red
        return
    }

    # Passo 2: Build
    Write-Host "`n[Passo 3/4] Iniciando Compilacao Headless do APK..." -ForegroundColor Cyan
    $buildScript = Join-Path $ScriptDir "Engine-Build.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $buildScript -ProjectPath $ProjectDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERRO] Falha na compilacao do APK Unity." -ForegroundColor Red
        return
    }

    # Passo 3: Pergunta Deploy
    $latestApk = Join-Path $ScriptDir "output\DCGO-android-latest.apk"
    if (Test-Path $latestApk) {
        Write-Host "`n============================================================" -ForegroundColor Green
        Write-Host "   BUILD CONCLUIDO COM SUCESSO! APK GERADO NA PASTA OUTPUT  " -ForegroundColor Green
        Write-Host "============================================================" -ForegroundColor Green
        
        $choice = Read-Host "`nDeseja instalar o APK e sincronizar o Deck no Tablet agora via USB? (S/N) [padrao: S]"
        if (-not $choice -or $choice -match "^[SsYy]") {
            Invoke-DeployAction -ApkFile $latestApk
        }
    }
}

function Invoke-DeployAction {
    param([string]$ApkFile)

    Write-Host "`n--- [3] Instalacao no Dispositivo Android (ADB) ---" -ForegroundColor Yellow
    if (-not $ApkFile) {
        $defaultApk = Join-Path $ScriptDir "output\DCGO-android-latest.apk"
        if (Test-Path $defaultApk) {
            $ApkFile = $defaultApk
        } else {
            $ApkFile = Read-Host "Informe o caminho do arquivo .apk para instalar"
            $ApkFile = $ApkFile.Trim('"')
        }
    }

    if (-not (Test-Path $ApkFile)) {
        Write-Host "[ERRO] Arquivo APK nao encontrado: $ApkFile" -ForegroundColor Red
        return
    }

    $deployScript = Join-Path $ScriptDir "Engine-Deploy.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $deployScript -ApkPath $ApkFile
}

# --- Modo Parametrizado (CLI direto) ---
if ($Mode) {
    switch ($Mode) {
        "git"    { Invoke-GitConversion -RepoUrl $GitUrl -Branch $GitBranch }
        "local"  { Invoke-LocalConversion -ProjectDir $TargetFolder }
        "deploy" { Invoke-DeployAction -ApkFile $TargetFolder }
        "check"  { Test-Environment }
    }
    exit 0
}

# --- Modo Interativo (Menu Principal) ---
do {
    Write-Header
    Write-Host " Escolha uma opcao:" -ForegroundColor White
    Write-Host "  [1] Converter Versao Direto do GitHub (Clonar + Patch + Build)" -ForegroundColor Green
    Write-Host "  [2] Converter Pasta Local do DCGO (Patch + Build)" -ForegroundColor Cyan
    Write-Host "  [3] Instalar Ultimo APK + Deck no Tablet (ADB USB)" -ForegroundColor Magenta
    Write-Host "  [4] Verificar Ambiente e Dispositivos Conectados" -ForegroundColor Yellow
    Write-Host "  [0] Sair" -ForegroundColor Gray
    Write-Host ""
    $opt = Read-Host "Opcao"

    switch ($opt) {
        "1" {
            Invoke-GitConversion
            Write-Host "`nPressione qualquer tecla para voltar ao menu..." -ForegroundColor Gray
            [void][System.Console]::ReadKey($true)
        }
        "2" {
            Invoke-LocalConversion
            Write-Host "`nPressione qualquer tecla para voltar ao menu..." -ForegroundColor Gray
            [void][System.Console]::ReadKey($true)
        }
        "3" {
            Invoke-DeployAction
            Write-Host "`nPressione qualquer tecla para voltar ao menu..." -ForegroundColor Gray
            [void][System.Console]::ReadKey($true)
        }
        "4" {
            Test-Environment
            Write-Host "`nPressione qualquer tecla para voltar ao menu..." -ForegroundColor Gray
            [void][System.Console]::ReadKey($true)
        }
        "0" {
            Write-Host "`nSaindo do DCGO Converter. Ate logo!`n" -ForegroundColor Cyan
            break
        }
        default {
            Write-Host "Opcao invalida. Tente novamente." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($opt -ne "0")
