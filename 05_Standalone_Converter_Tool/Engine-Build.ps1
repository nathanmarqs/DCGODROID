param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,
    [string]$UnityPath = "",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = 'Stop'
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path }

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $ScriptDir "output"
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Engine-Build] Starting Android Build" -ForegroundColor Cyan
Write-Host " Project: $ProjectPath" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Locate Unity Editor if path is not specified or does not exist
if ([string]::IsNullOrWhiteSpace($UnityPath) -or !(Test-Path -LiteralPath $UnityPath)) {
    $unityCandidates = @(
        "C:\Program Files\Unity\Hub\Editor\2021.3.45f2\Editor\Unity.exe",
        "C:\Program Files\Unity\Hub\Editor\*\Editor\Unity.exe",
        "D:\Program Files\Unity\Hub\Editor\*\Editor\Unity.exe",
        "C:\Program Files\Unity\Editor\Unity.exe"
    )
    $found = $null
    foreach ($cand in $unityCandidates) {
        $matched = Get-Item $cand -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($matched) { $found = $matched.FullName; break }
    }

    if ($found) {
        $UnityPath = $found
        Write-Host "  -> Unity detected dynamically: $UnityPath" -ForegroundColor Green
    } else {
        throw "Unity.exe not found on system. Please verify Unity Editor (2021.3.x) is installed."
    }
}

# 2. Configure log and output directory
$logDir = Join-Path $ScriptDir "logs"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logDir "build-$timestamp.log"

Write-Host "  -> Unity Path: $UnityPath" -ForegroundColor DarkGray
Write-Host "  -> Log File: $logFile" -ForegroundColor DarkGray

# 3. Launch Unity in batchmode with real-time monitoring
$arguments = "-batchmode -nographics -quit -projectPath `"$ProjectPath`" -buildTarget Android -executeMethod ProductionBuild.Android -logFile `"$logFile`""
$startTime = Get-Date

Write-Host "`n[1/3] Launching Unity Editor process..." -ForegroundColor Yellow
$process = Start-Process -FilePath $UnityPath -ArgumentList $arguments -WindowStyle Hidden -PassThru

# Monitor log in real time with visual animated progress bar
$lastReadPos = 0
$phasesSeen = @{}
$spinner = @('|', '/', '-', '\')
$spinnerIdx = 0
$currentPhaseText = "Initializing Unity Editor..."
$currentPct = 10
$importedCount = 0

while (!$process.HasExited) {
    Start-Sleep -Milliseconds 600
    $spinnerChar = $spinner[$spinnerIdx % $spinner.Length]
    $spinnerIdx++

    if (Test-Path -LiteralPath $logFile) {
        try {
            $stream = [System.IO.File]::Open($logFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            if ($stream.Length -gt $lastReadPos) {
                $stream.Seek($lastReadPos, [System.IO.SeekOrigin]::Begin) | Out-Null
                $reader = New-Object System.IO.StreamReader($stream)
                $chunk = $reader.ReadToEnd()
                $lastReadPos = $stream.Length
                $reader.Close()
                
                # Count imported assets
                $matches = [regex]::Matches($chunk, "Start importing")
                if ($matches.Count -gt 0) {
                    $importedCount += $matches.Count
                    $currentPhaseText = "Importing Assets ($importedCount items)"
                    $currentPct = [Math]::Min(35, 10 + [int]($importedCount / 400))
                }

                # Catch internal Unity progress bar status
                $progMatches = [regex]::Matches($chunk, "DisplayProgressbar:\s*([^\r\n]+)")
                if ($progMatches.Count -gt 0) {
                    $rawText = $progMatches[$progMatches.Count - 1].Groups[1].Value.Trim()
                    if ($rawText.Length -gt 38) { $rawText = $rawText.Substring(0, 35) + "..." }
                    $currentPhaseText = $rawText
                }

                if ($chunk -match "ReloadAssembly" -or $chunk -match "Domain Reload") {
                    $currentPhaseText = "Compiling Assemblies & Reloading Domain"
                    $currentPct = [Math]::Max($currentPct, 38)
                }
                if ($chunk -match "ScriptAssemblies" -or $chunk -match "bee_backend") {
                    $currentPhaseText = "Compiling Player C# Scripts"
                    $currentPct = [Math]::Max($currentPct, 45)
                }
                if ($chunk -match "Opening scene '([^']+)'") {
                    $sceneName = [regex]::Match($chunk, "Opening scene '([^']+)").Groups[1].Value
                    $sceneShort = [System.IO.Path]::GetFileNameWithoutExtension($sceneName)
                    $currentPhaseText = "Building Scene: $sceneShort"
                    $currentPct = [Math]::Max($currentPct, 55)
                }
                if ($chunk -match "Compiling shader" -or $chunk -match "Shader compilation" -or $chunk -match "UnityShaderCompiler") {
                    $currentPhaseText = "Compiling Shaders & Graphics Variants"
                    $currentPct = [Math]::Max($currentPct, 65)
                }
                if ($chunk -match "Building IL2CPP" -or $chunk -match "il2cpp\.exe" -or $chunk -match "il2cpp") {
                    $currentPhaseText = "Running IL2CPP (C# -> ARM64 Native)"
                    $currentPct = [Math]::Max($currentPct, 78)
                }
                if ($chunk -match "Building APK" -or $chunk -match "Gradle" -or $chunk -match "apkbuilder" -or $chunk -match "build\.gradle") {
                    $currentPhaseText = "Packaging Release APK via Gradle"
                    $currentPct = [Math]::Max($currentPct, 88)
                }
                if ($chunk -match "Build completed with a result of 'Succeeded'") {
                    $currentPhaseText = "Build Completed Successfully"
                    $currentPct = 100
                }
            }
            $stream.Close()
        } catch { }
    }

    $elapsed = (Get-Date) - $startTime
    $elapsedStr = "{0:D2}m {1:D2}s" -f [int]$elapsed.TotalMinutes, $elapsed.Seconds

    # Visual ASCII Progress Bar [================--------]
    $barTotal = 20
    $barFilled = [int](($currentPct / 100) * $barTotal)
    $barEmpty = [Math]::Max(0, $barTotal - $barFilled)
    $barStr = ("=" * $barFilled) + ("-" * $barEmpty)

    $statusLine = "`r  [$spinnerChar] [$barStr] {0,3}% | {1,-40} | Elapsed: {2} " -f $currentPct, $currentPhaseText, $elapsedStr
    Write-Host -NoNewline $statusLine
}
Write-Host ""

$duration = [Math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
Write-Host "`n[2/3] Unity process completed in $duration minutes with exit code: $($process.ExitCode)" -ForegroundColor $(if ($process.ExitCode -eq 0) { "Green" } else { "Red" })

if ($process.ExitCode -ne 0) {
    Write-Host "`n[ERROR] Unity reported build failure. Last 30 log lines:" -ForegroundColor Red
    Get-Content $logFile -Tail 30 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkRed }
    throw "Android build failed with exit code $($process.ExitCode). Check $logFile"
}

# 4. Locate APK generated by ProductionBuild
$sourceApk = Join-Path (Directory.GetParent($ProjectPath).FullName) "builds\Android\DCGO-android.apk"
if (!(Test-Path -LiteralPath $sourceApk)) {
    $sourceApk = Join-Path $ProjectPath "builds\Android\DCGO-android.apk"
}

if (!(Test-Path -LiteralPath $sourceApk)) {
    throw "APK not found after build. Please check the log: $logFile"
}

# 5. Copy to converter output folder
Write-Host "`n[3/3] Exporting APK to distribution directory..." -ForegroundColor Yellow
$destApkName = "DCGO-android-$timestamp.apk"
$destApkPath = Join-Path $OutputDirectory $destApkName
$latestApkPath = Join-Path $OutputDirectory "DCGO-android-latest.apk"

Copy-Item -LiteralPath $sourceApk -Destination $destApkPath -Force
Copy-Item -LiteralPath $sourceApk -Destination $latestApkPath -Force

$fileInfo = Get-Item -LiteralPath $destApkPath
$hash = (Get-FileHash -LiteralPath $destApkPath -Algorithm SHA256).Hash
$sizeMb = [Math]::Round($fileInfo.Length / 1MB, 2)

Write-Host "==========================================" -ForegroundColor Green
Write-Host " [Engine-Build] Build Completed Successfully!" -ForegroundColor Green
Write-Host " Generated APK: $destApkPath" -ForegroundColor Green
Write-Host " Latest Build Link: $latestApkPath" -ForegroundColor Green
Write-Host " File Size: $sizeMb MB" -ForegroundColor Green
Write-Host " SHA256: $hash" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

return $latestApkPath