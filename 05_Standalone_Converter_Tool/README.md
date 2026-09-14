# 🎮 DCGO Android Converter & Builder

An automated, self-contained suite to convert any version (current or future) of **DCGO (Digimon Card Game Online)** into a **100% functional, bug-free Android APK**, automatically patching graphics compatibility issues (Mali GPU shaders), screen orientation, and deck storage.

> *Nota: Para ler as instruções em Português, veja [`README_PT.md`](./README_PT.md).*

---

## ⚡ Quick Start (1-Click)

1. Double-click **`Converter-DCGO.bat`** (or the shortcut **`CONVERTER-DCGO.bat`** in the root project folder).
2. The interactive menu will open in your terminal:

```text
============================================================
             DCGO ANDROID CONVERTER & BUILDER               
   Automacao completa: Clone -> Patches Mali/Deck -> APK    
============================================================

 Escolha uma opcao:
  [1] Converter Versao Direto do GitHub (Clonar + Patch + Build)
  [2] Converter Pasta Local do DCGO (Patch + Build)
  [3] Instalar Ultimo APK + Deck no Tablet (ADB USB)
  [4] Verificar Ambiente e Dispositivos Conectados
  [0] Sair
```

---

## 🛠️ Usage Modes

### Option 1: Convert Directly from GitHub
- Enter any GitHub repository URL (e.g., `https://github.com/DCGO2/DCGO.git`) and specify the branch or tag.
- The converter clones the version into an isolated workspace, applies all patches, compiles the APK, and prompts if you want to install it on your Android tablet via USB.

### Option 2: Convert Local DCGO Folder
- If you already have the DCGO source code cloned on your machine (default: `C:\Users\Administrator\Desktop\dcgo android\PROD\DCGO`), select this option.
- The converter validates the directory, applies all fixes, and triggers the build.

### Option 3: Install Latest APK + Starter Deck to Tablet (ADB)
- Installs the newest compiled APK from `output/` directly onto any USB-connected Android device (`adb install -r`).
- Automatically copies the starter deck to the game's Android storage (`/sdcard/Android/data/com.DCGO.DCGO/files/Decks/StarterDeck_01.txt`).
- Wakes the screen and launches the game automatically.

### Option 4: Check Environment
- Performs automated diagnostics:
  - Unity Editor path (2021.3.x)
  - Android Build Support module (Unity Android Player)
  - Git version
  - ADB availability and connected Android devices.

---

## 🧩 Automatic Patches Applied

The converter automatically resolves all known Android issues:

1. **Mali GPU Shader Bugfix (Black Screens / Pink Textures / Yellow Boxes):**
   - Injects 6 mobile-optimized HLSL particle shaders into `Assets/Shader_Material/Shader/` to replace unsupported legacy shaders.
2. **Dual-Landscape Screen Orientation:**
   - Sets `ProjectSettings.asset` to enable AutoRotation between `LandscapeLeft` and `LandscapeRight` while disabling Portrait modes (prevents UI clipping and ANR freezes).
3. **Android Persistent Storage & Safe Deck Parsing:**
   - Routes deck reading/writing to `Application.persistentDataPath` in `StreamingAssetsUtility.cs`.
   - Protects `ContinuousController.cs` with defensive `int.TryParse` against formatting crashes.
4. **Release Mode IL2CPP Build Profile:**
   - Prepares headless compilation targeting ARM64 and OpenGLES3 with stripped debug symbols.

---

## 📁 Directory Structure

```text
DCGO-Converter/
├── Converter-DCGO.bat          # 1-Click batch launcher
├── DCGO-Converter.ps1          # Interactive PowerShell orchestrator
├── Engine-Patch.ps1            # Automated patch engine
├── Engine-Build.ps1            # Headless Unity batchmode builder
├── Engine-Deploy.ps1           # ADB installation and deck sync engine
├── README.md                   # English documentation
├── README_PT.md                # Portuguese documentation
├── patches/                    # Patch assets
│   ├── Shaders/                # Mobile Mali GPU shaders
│   ├── Editor/                 # ProductionBuild.cs
│   └── Decks/                  # Starter legal deck
├── output/                     # Compiled APKs
│   ├── DCGO-android-latest.apk # Always points to newest build
│   └── DCGO-android-<date>.apk # Timestamped build archive
└── logs/                       # Unity batchmode build logs
```

---

## 🃏 Adding Custom Decks

To add new decks that appear in the game:
1. Save your deck text file in DigimonCard.io format (card count + card ID, e.g. `4 Coronamon BT25-008`).
2. Add the required header at the top of the file:
   ```text
   Key Card: 0
   Deck Name: MyCustomDeck
   Deck Color: Red
   ```
3. Place the file in `patches/Decks/` before running, or push directly via ADB:
   `/sdcard/Android/data/com.DCGO.DCGO/files/Decks/`
