# 📱 DCGO Android Compatibility & Porting Kit
### Fixes, Shaders, Defensive Code & Automation for Official Android Support

> *Note: For the Portuguese version of this document, please see [`README_PT.md`](./README_PT.md).*

---

## 🎯 Executive Summary

This package provides all the necessary fixes, shaders, configuration profiles, and automation scripts to make **DCGO (Digimon Card Game Online)** officially build and run flawlessly on **Android** (smartphones, tablets, and Android emulation/handhelds).

All fixes in this kit were developed, tested, and validated on physical Android hardware (**ARM64, Android 13/14, Mali GPU**).

---

## 🔍 Key Problems Solved

### 1. Mali GPU Particle Shader Rendering Failures
* **Symptom:** On devices with ARM Mali GPUs (e.g., Samsung Galaxy Tab A8/A9, MediaTek/Exynos/Dimensity chipsets), particles and effects either render as solid pink/magenta, solid black screens, or yellow opaque boxes.
* **Root Cause:** Legacy/unsupported particle shaders fail to compile or bind properly under Universal Render Pipeline (URP) on Android Mali OpenGL ES 3.0 / Vulkan drivers.
* **Solution:** Replaced with 6 high-performance, mobile-optimized HLSL particle shaders located in `01_Shaders_Mali_Bugfix/`:
  * `Legacy-Particle-Add.shader`
  * `Legacy-Particle-Alpha.shader`
  * `Mobile-Particle-Add.shader`
  * `Mobile-Particle-Alpha.shader`
  * `Mobile-Particle-Multiply.shader`
  * `MobileMaskedAdditive.shader`

### 2. Dual-Landscape Screen Orientation
* **Symptom:** If portrait orientation is triggered, UI elements are clipped, aspect ratio breaks, or the game freezes on Android configuration changes. However, locking strictly to one side prevents players from turning their device when charging.
* **Solution:** Configure `PlayerSettings` to allow **AutoRotation between Landscape Left and Landscape Right only**, completely disabling portrait orientations.
* **Configuration:** Detailed in `04_ProjectSettings_Orientation/Orientation_Settings_Guide.md`.

### 3. Android Deck Storage & Resilient Deck Parsing
* **Symptom 1:** Android sandboxes application assets inside the APK container (`jar:file://`), preventing standard C# `System.IO.File` writing/listing of decks.
* **Symptom 2:** `ContinuousController.cs` throws unhandled `FormatException` and crashes deck loading if a deck file lacks an expected header line or if the filename does not contain an underscore when calling `.Split('_')[1]`.
* **Solution:**
  1. Route deck reading and writing to `Application.persistentDataPath + "/Decks"` on Android (see `StreamingAssetsUtility.cs`).
  2. Implement safe `int.TryParse` fallbacks and ternary split checks in `ContinuousController.cs` (see `02_Scripts_CSharp_Fixes/csharp_patches.patch`).

### 4. Headless Android Production Build Automation
* **Solution:** `Assets/Editor/ProductionBuild.cs` allows 1-command CI/CD or command-line compilation of clean Release APKs:
  * Targets **ARM64** (`AndroidArchitecture.ARM64`).
  * Enforces **IL2CPP** scripting backend for peak performance.
  * Uses **OpenGL ES 3.0** for maximum Mali/Adreno compatibility.
  * Generates clean Release builds (`BuildOptions.None`) without debug profiling overhead.

---

## 📂 Package Structure

```text
DCGO-Android-Developer-Kit/
├── README.md                        # This documentation (English - Main)
├── README_EN.md                     # English documentation
├── README_PT.md                     # Documentação em Português
├── 01_Shaders_Mali_Bugfix/          # 6 Mobile URP shaders (drop into Assets/Shader_Material/Shader/)
├── 02_Scripts_CSharp_Fixes/         # Defensive C# scripts + unified git diff patch
│   ├── ContinuousController.cs
│   ├── StreamingAssetsUtility.cs
│   └── csharp_patches.patch
├── 03_Editor_Automated_Build/       # Headless batchmode build script (Assets/Editor/ProductionBuild.cs)
├── 04_ProjectSettings_Orientation/  # ProjectSettings guide for dual landscape
└── 05_Standalone_Converter_Tool/    # Self-contained Windows 1-click build suite (DCGO-Converter)
```

---

## 🚀 How to Integrate into Upstream Repository

### Option A: Manual File Copy
1. Copy all files from `01_Shaders_Mali_Bugfix/` to:  
   `Assets/Shader_Material/Shader/`
2. Copy `02_Scripts_CSharp_Fixes/ContinuousController.cs` and `StreamingAssetsUtility.cs` to:  
   `Assets/Scripts/Script/`
3. Copy `03_Editor_Automated_Build/ProductionBuild.cs` to:  
   `Assets/Editor/`
4. In Unity Project Settings -> Player -> Android:  
   Enable AutoRotation with **Landscape Left** and **Landscape Right** enabled, **Portrait** disabled.

### Option B: Using Git Patch
Run from the root of the DCGO repository:
```bash
git apply 02_Scripts_CSharp_Fixes/csharp_patches.patch
```

---

## 🛠️ Automated Converter Suite

Also included in `05_Standalone_Converter_Tool/` is the **DCGO-Converter** tool:
* Double-click `Converter-DCGO.bat` to launch an interactive CLI.
* Automatically clones from GitHub, applies all patches, compiles APKs via Unity headless batchmode, and optionally installs/syncs decks to any USB-connected Android tablet via ADB.

---

*Authored and verified for the Digimon Card Game Online Community.*
