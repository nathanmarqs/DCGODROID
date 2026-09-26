param(
    [Parameter(Mandatory=$true)]
    [Alias("TargetProject")]
    [string]$ProjectPath
)

$ErrorActionPreference = 'Stop'
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Engine-Patch] Starting Patch Deployment" -ForegroundColor Cyan
Write-Host " Target Project: $ProjectPath" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (!(Test-Path -LiteralPath $ProjectPath)) {
    throw "Project directory not found: $ProjectPath"
}

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path }

$patchesDir = Join-Path $ScriptDir "patches"

# 0. Inject Original Locked Assets (SCI-FI UI Components, Sound, StreamingAssets, AddOns, Effects)
$lockedAssetsSrc = Join-Path $patchesDir "Assets-Locked"
if (Test-Path -LiteralPath $lockedAssetsSrc) {
    Write-Host "[0/6] Restoring Original Locked DCGO Assets (SCI-FI UI, Sound, StreamingAssets)..." -ForegroundColor Yellow
    Get-ChildItem -LiteralPath $lockedAssetsSrc -Recurse | ForEach-Object {
        $rel = $_.FullName.Substring($lockedAssetsSrc.Length).TrimStart('\', '/')
        $dest = Join-Path (Join-Path $ProjectPath "Assets") $rel
        if ($_.PSIsContainer) {
            if (-not (Test-Path -LiteralPath $dest)) {
                New-Item -ItemType Directory -Path $dest -Force | Out-Null
            }
        } else {
            if (-not (Test-Path -LiteralPath $dest)) {
                $p = Split-Path -Parent $dest
                if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
                Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
            }
        }
    }
    Write-Host "  -> Original DCGO UI, Sound & Effect Assets verified and restored!" -ForegroundColor Green
}

# 1. Inject Fixed Shaders (Mali GPU Bugfix)
Write-Host "[1/6] Injecting Mobile & URP Particle Shaders..." -ForegroundColor Yellow
$targetShaderDir = Join-Path $ProjectPath "Assets\Shader_Material\Shader"
if (!(Test-Path -LiteralPath $targetShaderDir)) {
    New-Item -ItemType Directory -Path $targetShaderDir -Force | Out-Null
}

$shaders = @(
    "Legacy-Particle-Add.shader",
    "Legacy-Particle-Alpha.shader",
    "Mobile-Particle-Add.shader",
    "Mobile-Particle-Alpha.shader",
    "Mobile-Particle-Multiply.shader",
    "DL_Additive.shader"
)

foreach ($sh in $shaders) {
    $src = Join-Path $patchesDir "Shaders\$sh"
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $targetShaderDir $sh) -Force
        Write-Host "  -> Injected: $sh" -ForegroundColor Green
    }
    $metaSrc = "$src.meta"
    if (Test-Path -LiteralPath $metaSrc) {
        Copy-Item -LiteralPath $metaSrc -Destination (Join-Path $targetShaderDir "$sh.meta") -Force
        Write-Host "  -> Injected GUID meta: $sh.meta" -ForegroundColor Green
    }
}

$envShaderSrc = Join-Path $patchesDir "Shaders\MobileMaskedAdditive.shader"
if (Test-Path -LiteralPath $envShaderSrc) {
    $envShaderDest = Join-Path $ProjectPath "Assets\Effect\DigitalEnvironmentEffects\Shaders"
    if (!(Test-Path -LiteralPath $envShaderDest)) {
        New-Item -ItemType Directory -Path $envShaderDest -Force | Out-Null
    }
    Copy-Item -LiteralPath $envShaderSrc -Destination (Join-Path $envShaderDest "MobileMaskedAdditive.shader") -Force
    Write-Host "  -> Injected: MobileMaskedAdditive.shader" -ForegroundColor Green
}

# 2. Inject Automated Build Script (ProductionBuild.cs)
Write-Host "[2/5] Injecting Release Build Script..." -ForegroundColor Yellow
$editorDir = Join-Path $ProjectPath "Assets\Editor"
if (!(Test-Path -LiteralPath $editorDir)) {
    New-Item -ItemType Directory -Path $editorDir -Force | Out-Null
}
$buildScriptSrc = Join-Path $patchesDir "Editor\ProductionBuild.cs"
Copy-Item -LiteralPath $buildScriptSrc -Destination (Join-Path $editorDir "ProductionBuild.cs") -Force
Write-Host "  -> Injected: Assets\Editor\ProductionBuild.cs" -ForegroundColor Green

# 3. Patch ProjectSettings.asset (Dual Landscape + Android settings)
Write-Host "[3/5] Configuring ProjectSettings (Dual-Landscape AutoRotation)..." -ForegroundColor Yellow
$projectSettingsPath = Join-Path $ProjectPath "ProjectSettings\ProjectSettings.asset"
if (Test-Path -LiteralPath $projectSettingsPath) {
    $content = [System.IO.File]::ReadAllText($projectSettingsPath)
    
    $content = $content -replace "allowedAutorotateToPortrait:\s*[01]", "allowedAutorotateToPortrait: 0"
    $content = $content -replace "allowedAutorotateToPortraitUpsideDown:\s*[01]", "allowedAutorotateToPortraitUpsideDown: 0"
    $content = $content -replace "allowedAutorotateToLandscapeRight:\s*[01]", "allowedAutorotateToLandscapeRight: 1"
    $content = $content -replace "allowedAutorotateToLandscapeLeft:\s*[01]", "allowedAutorotateToLandscapeLeft: 1"
    $content = $content -replace "defaultInterfaceOrientation:\s*\d+", "defaultInterfaceOrientation: 3"
    
    [System.IO.File]::WriteAllText($projectSettingsPath, $content)
    Write-Host "  -> ProjectSettings.asset configured for LandscapeLeft + LandscapeRight" -ForegroundColor Green
} else {
    Write-Host "  [Warning] ProjectSettings.asset not found at $projectSettingsPath" -ForegroundColor DarkYellow
}

# 3.1 Patch GraphicsSettings.asset (Ensure essential mobile shaders are compiled)
$graphicsSettingsPath = Join-Path $ProjectPath "ProjectSettings\GraphicsSettings.asset"
if (Test-Path -LiteralPath $graphicsSettingsPath) {
    $gContent = [System.IO.File]::ReadAllText($graphicsSettingsPath)
    if ($gContent -notmatch "715a03c941bb4a7daed9541702fdc55f") {
        $shaderEntries = @"
  - {fileID: 4800000, guid: 715a03c941bb4a7daed9541702fdc55f, type: 3}
  - {fileID: 4800000, guid: 0c5c060a0fee43e38cb24e759a4aebbf, type: 3}
  - {fileID: 4800000, guid: 0a345ba118d3415bb87dabad136fd231, type: 3}
  m_PreloadedShaders:
"@
        $gContent = $gContent -replace "  m_PreloadedShaders:", $shaderEntries
        [System.IO.File]::WriteAllText($graphicsSettingsPath, $gContent)
        Write-Host "  -> GraphicsSettings.asset patched with AlwaysIncludedShaders (Mali/URP fix)" -ForegroundColor Green
    }
}

# 4. Patch C# Scripts (StreamingAssetsUtility + ContinuousController)
Write-Host "[4/5] Applying defensive C# code patches..." -ForegroundColor Yellow
$sauPath = Join-Path $ProjectPath "Assets\Scripts\Script\StreamingAssetsUtility.cs"
if (Test-Path -LiteralPath $sauPath) {
    $sauContent = [System.IO.File]::ReadAllText($sauPath)
    if ($sauContent -notmatch "Application\.persistentDataPath") {
        # Redirect Decks to persistentDataPath on Android
        $sauContent = $sauContent -replace 'public static string GetDecksPath\(\)\s*\{', "public static string GetDecksPath()`n    {`n#if UNITY_ANDROID && !UNITY_EDITOR`n        string path = Path.Combine(Application.persistentDataPath, `"Decks`").Replace(`"\\`", `"/`");`n        if (!Directory.Exists(path)) Directory.CreateDirectory(path);`n        return path;`n#endif"
        [System.IO.File]::WriteAllText($sauPath, $sauContent)
        Write-Host "  -> StreamingAssetsUtility.cs patched for persistentDataPath" -ForegroundColor Green
    } else {
        Write-Host "  -> StreamingAssetsUtility.cs already compatible" -ForegroundColor DarkGray
    }
}

# 5. Patch ContinuousController (Safe Deck Loading)
$ccPath = Join-Path $ProjectPath "Assets\Scripts\Script\ContinuousController.cs"
if (Test-Path -LiteralPath $ccPath) {
    $ccContent = [System.IO.File]::ReadAllText($ccPath)
    if ($ccContent -match "int KeyCard = int\.Parse") {
        $ccContent = $ccContent -replace 'int KeyCard = int\.Parse\(sr\.ReadLine\(\)\.Replace\("Key Card: ", ""\)\);', 'string rawKey = sr.ReadLine(); int KeyCard = 0; if (!string.IsNullOrEmpty(rawKey)) { int.TryParse(rawKey.Replace("Key Card: ", "").Trim(), out KeyCard); }'
        $ccContent = $ccContent -replace 'int SortValue = int\.Parse\(sr\.ReadLine\(\)\.Replace\("Sort Index: ", ""\)\);', 'string rawSort = sr.ReadLine(); int SortValue = 0; if (!string.IsNullOrEmpty(rawSort)) { int.TryParse(rawSort.Replace("Sort Index: ", "").Trim(), out SortValue); }'
        $ccContent = $ccContent -replace 'fileName\.Split\("_"\)\[1\]', '(fileName.Contains("_") ? fileName.Split("_")[1] : fileName)'
        [System.IO.File]::WriteAllText($ccPath, $ccContent)
        Write-Host "  -> ContinuousController.cs protected against deck parsing exceptions" -ForegroundColor Green
    } else {
        Write-Host "  -> ContinuousController.cs already protected" -ForegroundColor DarkGray
    }
}

# 6. Patch FieldPermanentCard & HandCard (Fix upstream Android compile errors: pressing -> _pressing, requiredTime -> _requiredTime)
Write-Host "[5/5] Fixing upstream Android syntax bugs (FieldPermanentCard & HandCard)..." -ForegroundColor Yellow

$fpcPath = Join-Path $ProjectPath "Assets\Scripts\Script\FieldPermanentCard.cs"
if (Test-Path -LiteralPath $fpcPath) {
    $fpcContent = [System.IO.File]::ReadAllText($fpcPath)
    $fpcContent = $fpcContent -replace '__pressing', '_pressing'
    $fpcContent = $fpcContent -replace '__requiredTime', '_requiredTime'
    $fpcContent = $fpcContent -replace '\bpressing\b', '_pressing'
    $fpcContent = $fpcContent -replace '\brequiredTime\b', '_requiredTime'
    [System.IO.File]::WriteAllText($fpcPath, $fpcContent)
    Write-Host "  -> FieldPermanentCard.cs Android syntax normalized!" -ForegroundColor Green
}

$hcPath = Join-Path $ProjectPath "Assets\Scripts\Script\HandCard.cs"
if (Test-Path -LiteralPath $hcPath) {
    $hcContent = [System.IO.File]::ReadAllText($hcPath)
    $hcContent = $hcContent -replace '__pressing', '_pressing'
    $hcContent = $hcContent -replace '__requiredTime', '_requiredTime'
    $hcContent = $hcContent -replace '\bpressing\b', '_pressing'
    $hcContent = $hcContent -replace '\brequiredTime\b', '_requiredTime'
    [System.IO.File]::WriteAllText($hcPath, $hcContent)
    Write-Host "  -> HandCard.cs Android syntax normalized!" -ForegroundColor Green
}

# 7. Apply Core Android C# Script Patches (StreamingAssetsUtility & ContinuousController)
$scriptsPatchDir = Join-Path $patchesDir "Scripts"
if (Test-Path -LiteralPath $scriptsPatchDir) {
    Get-ChildItem -LiteralPath $scriptsPatchDir -Filter "*.cs" | ForEach-Object {
        $dest = Join-Path $ProjectPath "Assets\Scripts\Script\$($_.Name)"
        Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
        Write-Host "  -> Applied Core Script: $($_.Name)" -ForegroundColor Green
    }
}

# 8. Unity 6 Compatibility Fix (GetInstanceID -> GetHashCode)
Write-Host "[8/8] Applying Unity 6 compatibility fixes..." -ForegroundColor Yellow
$csFiles = Get-ChildItem -Path (Join-Path $ProjectPath "Assets") -Recurse -Filter "*.cs"
foreach ($file in $csFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match "GetInstanceID\(\)") {
        $content = $content -replace "GetInstanceID\(\)", "GetHashCode()"
        Set-Content -Path $file.FullName -Value $content -NoNewline
    }
}
Write-Host "  -> Unity 6 fixes applied (GetInstanceID -> GetHashCode)" -ForegroundColor Green

Write-Host "==========================================" -ForegroundColor Green
Write-Host " [Engine-Patch] All patches applied successfully!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
