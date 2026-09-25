<div align="center">
  <h1>🎮 DCGO Android Converter & Builder</h1>
  <p><i>The ultimate, fully-automated toolkit to bring Digimon Card Game Online to your mobile device.</i></p>

  ![Unity](https://img.shields.io/badge/Unity-2021.3.x-black?style=for-the-badge&logo=unity)
  ![Android](https://img.shields.io/badge/Android-Ready-3DDC84?style=for-the-badge&logo=android&logoColor=white)
  ![PowerShell](https://img.shields.io/badge/PowerShell-Automated-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
</div>

---

> *Note: Para ler as instruções em Português, veja [`README_PT.md`](./README_PT.md).*

Welcome to the **DCGO Android Converter**. This self-contained suite automatically patches, compiles, and deploys any version of **DCGO (Digimon Card Game Online)** directly to your Android device. No manual coding or shader fixing required.

## ✨ Key Features
- **🤖 Zero-Touch Build Pipeline:** Fetches directly from GitHub and compiles seamlessly in the background.
- **📱 Mobile-First Optimization:** Automatically fixes known Android compatibility issues, including Mali GPU shader crashes (pink textures/black screens) and UI scaling.
- **⚡ Direct ADB Deployment:** Pushes the compiled game and your custom decks straight to your connected Android device.

---

## 🚀 Quick Start (1-Click)

1. Double-click the **`Converter-DCGO.bat`** shortcut in the project root.
2. An interactive terminal will guide you through the process:

```text
============================================================
             DCGO ANDROID CONVERTER & BUILDER               
   Full Automation: Clone -> Patches Mali/Deck -> APK    
============================================================

 Choose an option:
  [1] Convert Direct from GitHub (Clone + Patch + Build)
  [2] Convert Local DCGO Folder (Patch + Build)
  [3] Install Latest APK + Starter Deck to Device (ADB USB)
  [4] Check Environment & Connected Devices
  [0] Exit
```

---

## 🛠️ Usage Guide

| Option | Description | Ideal For |
| :--- | :--- | :--- |
| **[1] GitHub Clone** | Pulls the latest source code straight from the official repository, patches it, and builds a fresh APK. | First-time setups or major updates. |
| **[2] Local Folder** | Points to an existing local DCGO project folder (`PROD/DCGO`). Patches the files locally and compiles. | Developers making custom local changes. |
| **[3] Deploy to Device** | Automatically installs the latest compiled APK (`output/`) to a USB-connected Android device and syncs starter decks. | Pushing the game to your Android device. |
| **[4] Diagnostics** | Verifies your Unity installation, Android SDK/NDK paths, Git, and ADB device connections. | Troubleshooting setup issues. |

---

## 🧩 Under the Hood (Automated Patches)

The converter acts as a bridge between the PC-centric original codebase and the mobile ecosystem. Here is what it does automatically behind the scenes:

*   **Graphics & Shaders:** Injects custom-compiled HLSL mobile shaders (`Mobile-Particle-Add`, `DL_Additive`, etc.) to replace legacy PC particles that cause Mali GPUs to render magenta squares.
*   **Screen Orientation:** Overrides `ProjectSettings.asset` to enforce strict `LandscapeLeft` / `LandscapeRight` auto-rotation, preventing UI clipping bugs and portrait-mode crashes.
*   **Persistent Storage Routing:** Modifies `StreamingAssetsUtility.cs` on the fly to route all deck reading/writing safely to Android's `persistentDataPath`.
*   **Crash Prevention:** Wraps deck parsing logic in `ContinuousController.cs` with defensive `TryParse` methods to prevent fatal app crashes caused by malformed text files.

---

## 📁 Directory Structure

```text
DCGO-Converter/
├── Converter-DCGO.bat          # 1-Click interactive launcher
├── DCGO-Converter.ps1          # Core PowerShell orchestrator
├── Engine-Patch.ps1            # Code injection and shader patcher
├── Engine-Build.ps1            # Headless Unity IL2CPP compiler
├── Engine-Deploy.ps1           # ADB installation & storage sync
├── patches/                    # Repository of Android-ready assets (Shaders, Scripts, Decks)
├── output/                     # Compiled APKs ready for distribution
└── logs/                       # Build logs for debugging
```

---

## 🃏 Importing Custom Decks

Decks are fully supported and synced directly to your Android device.

1. Save your deck text file in standard **DigimonCard.io** format.
2. Ensure the file contains the required header:
   ```text
   Key Card: 0
   Deck Name: My Custom Deck
   Sort Index: 0
   ```
3. Place it in your device's internal storage at:
   `/sdcard/Android/data/com.DCGO.DCGO/files/Decks/`
   *(Or just use **Option 3** in the converter to push the Starter Deck automatically).*

---
<div align="center">
  <i>Built for the DCGO Community • Seamless Mobile Card Battles</i>
</div>
