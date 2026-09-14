# Dual-Landscape Screen Orientation Setup (Android)

## Problem Description
By default, the game or engine defaults to Portrait or single Landscape without proper Autorotation settings.
On Android tablets and phones, if Portrait is allowed or triggered, the UI layout aspect ratio breaks, cutting off UI elements, or causes an ANR / crash upon orientation change.
Furthermore, players need to be able to flip their device 180 degrees (Landscape Left vs. Landscape Right) depending on where their charger/headphones are plugged in.

## Unity Editor Setup
In Unity Editor:
1. Open **Project Settings** -> **Player** -> **Android Tab** (robot icon).
2. Go to **Resolution and Presentation**:
   - **Default Interface Orientation**: `Auto Rotation`
   - **Allowed Orientations for Auto Rotation**:
     - `Portrait`: **UNCHECKED (False)**
     - `Portrait Upside Down`: **UNCHECKED (False)**
     - `Landscape Left`: **CHECKED (True)**
     - `Landscape Right`: **CHECKED (True)**

## ProjectSettings.asset Configuration (Direct File Edit)
In `ProjectSettings/ProjectSettings.asset`:
```yaml
  defaultInterfaceOrientation: 3
  allowedAutorotateToPortrait: 0
  allowedAutorotateToPortraitUpsideDown: 0
  allowedAutorotateToLandscapeLeft: 1
  allowedAutorotateToLandscapeRight: 1
  useOSAutorotation: 1
```

## Programmatic Setup (C# Editor Script)
You can also set it automatically in your build script before compiling:
```csharp
PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
PlayerSettings.allowedAutorotateToLandscapeLeft = true;
PlayerSettings.allowedAutorotateToLandscapeRight = true;
PlayerSettings.allowedAutorotateToPortrait = false;
PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
```
