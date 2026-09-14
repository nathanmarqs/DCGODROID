param(
    [Parameter(Mandatory=$true)]
    [Alias("TargetProject")]
    [string]$ProjectPath
)

$ErrorActionPreference = 'Stop'
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " [Engine-Patch] Iniciando aplicação de patches" -ForegroundColor Cyan
Write-Host " Projeto Alvo: $ProjectPath" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (!(Test-Path -LiteralPath $ProjectPath)) {
    throw "Diretório do projeto não encontrado: $ProjectPath"
}

$patchesDir = Join-Path $PSScriptRoot "patches"

# 1. Injetar Shaders Corrigidos (Mali GPU Bugfix)
Write-Host "[1/5] Injetando Shaders Mobile e Partículas URP..." -ForegroundColor Yellow
$targetShaderDir = Join-Path $ProjectPath "Assets\Shader_Material\Shader"
if (!(Test-Path -LiteralPath $targetShaderDir)) {
    New-Item -ItemType Directory -Path $targetShaderDir -Force | Out-Null
}

$shaders = @(
    "Legacy-Particle-Add.shader",
    "Legacy-Particle-Alpha.shader",
    "Mobile-Particle-Add.shader",
    "Mobile-Particle-Alpha.shader",
    "Mobile-Particle-Multiply.shader"
)

foreach ($sh in $shaders) {
    $src = Join-Path $patchesDir "Shaders\$sh"
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $targetShaderDir $sh) -Force
        Write-Host "  -> Injetado: $sh" -ForegroundColor Green
    }
}

$envShaderSrc = Join-Path $patchesDir "Shaders\MobileMaskedAdditive.shader"
if (Test-Path -LiteralPath $envShaderSrc) {
    $envShaderDest = Join-Path $ProjectPath "Assets\Effect\DigitalEnvironmentEffects\Shaders"
    if (!(Test-Path -LiteralPath $envShaderDest)) {
        New-Item -ItemType Directory -Path $envShaderDest -Force | Out-Null
    }
    Copy-Item -LiteralPath $envShaderSrc -Destination (Join-Path $envShaderDest "MobileMaskedAdditive.shader") -Force
    Write-Host "  -> Injetado: MobileMaskedAdditive.shader" -ForegroundColor Green
}

# 2. Injetar Script de Build Automatizado (ProductionBuild.cs)
Write-Host "[2/5] Injetando Script de Compilação Release..." -ForegroundColor Yellow
$editorDir = Join-Path $ProjectPath "Assets\Editor"
if (!(Test-Path -LiteralPath $editorDir)) {
    New-Item -ItemType Directory -Path $editorDir -Force | Out-Null
}
$buildScriptSrc = Join-Path $patchesDir "Editor\ProductionBuild.cs"
Copy-Item -LiteralPath $buildScriptSrc -Destination (Join-Path $editorDir "ProductionBuild.cs") -Force
Write-Host "  -> Injetado: Assets\Editor\ProductionBuild.cs" -ForegroundColor Green

# 3. Patch ProjectSettings.asset (Dual Landscape + Android settings)
Write-Host "[3/5] Configurando ProjectSettings (Autorrotação Paisagem Dupla)..." -ForegroundColor Yellow
$projectSettingsPath = Join-Path $ProjectPath "ProjectSettings\ProjectSettings.asset"
if (Test-Path -LiteralPath $projectSettingsPath) {
    $content = [System.IO.File]::ReadAllText($projectSettingsPath)
    
    $content = $content -replace "allowedAutorotateToPortrait:\s*[01]", "allowedAutorotateToPortrait: 0"
    $content = $content -replace "allowedAutorotateToPortraitUpsideDown:\s*[01]", "allowedAutorotateToPortraitUpsideDown: 0"
    $content = $content -replace "allowedAutorotateToLandscapeRight:\s*[01]", "allowedAutorotateToLandscapeRight: 1"
    $content = $content -replace "allowedAutorotateToLandscapeLeft:\s*[01]", "allowedAutorotateToLandscapeLeft: 1"
    $content = $content -replace "defaultInterfaceOrientation:\s*\d+", "defaultInterfaceOrientation: 3"
    
    [System.IO.File]::WriteAllText($projectSettingsPath, $content)
    Write-Host "  -> ProjectSettings.asset configurado para LandscapeLeft + LandscapeRight" -ForegroundColor Green
} else {
    Write-Host "  [Aviso] ProjectSettings.asset não encontrado em $projectSettingsPath" -ForegroundColor DarkYellow
}

# 4. Patch C# Scripts (StreamingAssetsUtility + ContinuousController)
Write-Host "[4/5] Aplicando correções defensivas de código C#..." -ForegroundColor Yellow
$sauPath = Join-Path $ProjectPath "Assets\Scripts\Script\StreamingAssetsUtility.cs"
if (Test-Path -LiteralPath $sauPath) {
    $sauContent = [System.IO.File]::ReadAllText($sauPath)
    if ($sauContent -notmatch "Application\.persistentDataPath") {
        # Garantir redirecionamento de Decks no Android
        $sauContent = $sauContent -replace 'public static string GetDecksPath\(\)\s*\{', "public static string GetDecksPath()`n    {`n#if UNITY_ANDROID && !UNITY_EDITOR`n        string path = Path.Combine(Application.persistentDataPath, `"Decks`").Replace(`"\\`", `"/`");`n        if (!Directory.Exists(path)) Directory.CreateDirectory(path);`n        return path;`n#endif"
        [System.IO.File]::WriteAllText($sauPath, $sauContent)
        Write-Host "  -> StreamingAssetsUtility.cs corrigido para persistentDataPath" -ForegroundColor Green
    } else {
        Write-Host "  -> StreamingAssetsUtility.cs já compatível" -ForegroundColor DarkGray
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
        Write-Host "  -> ContinuousController.cs protegido contra falhas de parsing de Decks" -ForegroundColor Green
    } else {
        Write-Host "  -> ContinuousController.cs já protegido" -ForegroundColor DarkGray
    }
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host " [Engine-Patch] Todos os patches aplicados com sucesso!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green