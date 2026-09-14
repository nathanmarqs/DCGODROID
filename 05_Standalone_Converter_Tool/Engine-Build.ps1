param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,
    [string]$UnityPath = "C:\Program Files\Unity\Hub\Editor\2021.3.45f2\Editor\Unity.exe",
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "output")
)

$ErrorActionPreference = 'Stop'
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Engine-Build] Iniciando Compilação Android" -ForegroundColor Cyan
Write-Host " Projeto: $ProjectPath" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Localizar Unity Editor se o caminho padrão não existir
if (!(Test-Path -LiteralPath $UnityPath)) {
    $found = Get-ChildItem "C:\Program Files\Unity\Hub\Editor\*\Editor\Unity.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $UnityPath = $found.FullName
        Write-Host "  -> Unity detectado dinamicamente: $UnityPath" -ForegroundColor Green
    } else {
        throw "Unity.exe não encontrado em: $UnityPath"
    }
}

# 2. Configurar diretório de log e saída
$logDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logDir "build-$timestamp.log"

Write-Host "  -> Unity Path: $UnityPath" -ForegroundColor DarkGray
Write-Host "  -> Log File: $logFile" -ForegroundColor DarkGray

# 3. Disparar Unity em batchmode com monitoramento de progresso
$arguments = "-batchmode -nographics -quit -projectPath `"$ProjectPath`" -buildTarget Android -executeMethod ProductionBuild.Android -logFile `"$logFile`""
$startTime = Get-Date

Write-Host "`n[1/3] Iniciando processo do Unity Editor..." -ForegroundColor Yellow
$process = Start-Process -FilePath $UnityPath -ArgumentList $arguments -WindowStyle Hidden -PassThru

# Monitorar log em tempo real
$lastReadPos = 0
$phasesSeen = @{}

while (!$process.HasExited) {
    Start-Sleep -Seconds 3
    if (Test-Path -LiteralPath $logFile) {
        try {
            $stream = [System.IO.File]::Open($logFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            if ($stream.Length -gt $lastReadPos) {
                $stream.Seek($lastReadPos, [System.IO.SeekOrigin]::Begin) | Out-Null
                $reader = New-Object System.IO.StreamReader($stream)
                $chunk = $reader.ReadToEnd()
                $lastReadPos = $stream.Length
                $reader.Close()
                
                # Identificar fases principais
                if ($chunk -match "Scripts has have been compiled" -and !$phasesSeen.ContainsKey("Scripts")) {
                    $phasesSeen["Scripts"] = $true
                    Write-Host "  [*] Scripts C# compilados com sucesso." -ForegroundColor Green
                }
                if ($chunk -match "Compiling shader" -and !$phasesSeen.ContainsKey("Shaders")) {
                    $phasesSeen["Shaders"] = $true
                    Write-Host "  [*] Compilando shaders e variantes gráficas..." -ForegroundColor Cyan
                }
                if ($chunk -match "Building IL2CPP" -and !$phasesSeen.ContainsKey("IL2CPP")) {
                    $phasesSeen["IL2CPP"] = $true
                    Write-Host "  [*] Executando conversor IL2CPP para ARM64..." -ForegroundColor Cyan
                }
                if ($chunk -match "Building APK" -and !$phasesSeen.ContainsKey("APK")) {
                    $phasesSeen["APK"] = $true
                    Write-Host "  [*] Empacotando APK final via Gradle..." -ForegroundColor Cyan
                }
            }
            $stream.Close()
        } catch { }
    }
}

$duration = [Math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
Write-Host "`n[2/3] Processo do Unity finalizado em $duration minutos com código: $($process.ExitCode)" -ForegroundColor $(if ($process.ExitCode -eq 0) { "Green" } else { "Red" })

if ($process.ExitCode -ne 0) {
    Write-Host "`n[ERRO] O Unity retornou falha na compilação. Últimas 30 linhas do log:" -ForegroundColor Red
    Get-Content $logFile -Tail 30 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkRed }
    throw "Build Android falhou com código $($process.ExitCode). Verifique $logFile"
}

# 4. Localizar APK gerado pelo ProductionBuild
$sourceApk = Join-Path (Directory.GetParent($ProjectPath).FullName) "builds\Android\DCGO-android.apk"
if (!(Test-Path -LiteralPath $sourceApk)) {
    $sourceApk = Join-Path $ProjectPath "builds\Android\DCGO-android.apk"
}

if (!(Test-Path -LiteralPath $sourceApk)) {
    throw "APK não encontrado após a compilação. Verifique o log: $logFile"
}

# 5. Copiar para a pasta de saída do conversor
Write-Host "`n[3/3] Exportando APK para a pasta de distribuição..." -ForegroundColor Yellow
$destApkName = "DCGO-android-$timestamp.apk"
$destApkPath = Join-Path $OutputDirectory $destApkName
$latestApkPath = Join-Path $OutputDirectory "DCGO-android-latest.apk"

Copy-Item -LiteralPath $sourceApk -Destination $destApkPath -Force
Copy-Item -LiteralPath $sourceApk -Destination $latestApkPath -Force

$fileInfo = Get-Item -LiteralPath $destApkPath
$hash = (Get-FileHash -LiteralPath $destApkPath -Algorithm SHA256).Hash
$sizeMb = [Math]::Round($fileInfo.Length / 1MB, 2)

Write-Host "==========================================" -ForegroundColor Green
Write-Host " [Engine-Build] Compilação Concluída com Sucesso!" -ForegroundColor Green
Write-Host " APK Gerado: $destApkPath" -ForegroundColor Green
Write-Host " Link Mais Recente: $latestApkPath" -ForegroundColor Green
Write-Host " Tamanho: $sizeMb MB" -ForegroundColor Green
Write-Host " SHA256: $hash" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

return $latestApkPath