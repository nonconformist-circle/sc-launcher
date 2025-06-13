# sc-launcher
**Play Star Citizen on Linux**

## Overview

This script helps you install and run the *Star Citizen* launcher on Linux using Proton via Steam.

## Why Use Steam?

Running Star Citizen through Steam offers several benefits on Linux:

- **Proton Integration**: Steam provides first-class Proton support, allowing compatibility layers to run Windows games like Star Citizen smoothly.
- **Shader Cache Management**: Steam handles and caches compiled Vulkan shaders per user and game, reducing stutter and improving performance over time.
- **Isolated Game Data**: Steam keeps game files, Proton prefixes, and shader data organized within a predictable directory structure, simplifying troubleshooting and backups.
- **Proton Updates and Overrides**: You can easily switch or update your Proton version using Steam’s UI or ProtonQT, without affecting other games or applications.
- **Launch Scripts and Compatibility**: Steam makes it easy to pass arguments, use launch wrappers (like `sc-launcher.sh`), and enforce compatibility settings.
- **Library Management**: Steam allows custom installation paths and library folders, which is helpful for managing the large disk space Star Citizen requires.
- **Input and Overlay Features**: Steam Input can be used to configure and remap gamepads or HOTAS setups, and the Steam overlay can provide useful in-game tools, like video recording, screenshots, chat, voip.

**In short:** Steam acts as a convenient and flexible launcher layer, helping to manage the complexity of running a Windows-only game like Star Citizen on Linux with Proton.

## Requirements

- Proton (preferably Proton GE or Proton CachyOS)
- Steam client installed (with Proton support enabled)
- ProtonQT installed (for downloading and managing Proton versions)
- Star Citizen installer from RSI website

---

## Installation Steps

### 1. Install Proton via ProtonQT

- Use **ProtonQT** to download your desired Proton version:
  - Proton GE is a good option.
  - Proton CachyOS is potentially better.
- You can also use ProtonQT later to update your Proton version.

### 2. Prepare Installation Directory

- Place `sc-launcher.sh` in the directory where you want to install Star Citizen.
- In the same directory, create a folder named `Roberts Space Industries`.
- Download the RSI installer (`RSI Launcher-Setup-*.exe`) from the official RSI homepage into this subfolder (`Roberts Space Industries`).

### 3. Add to Steam

- Open Steam and go to:  
  **"Add a Game" → "Add a Non-Steam Game" → "Browse"**  
  Select the `sc-launcher.sh` script.

### 4. Configure Steam Shortcut

- Locate the new shortcut in your Steam Library (name it something like "Star Citizen Launcher").
- Open **Properties**:
  - Under **Shortcut**, for the initial install/update **only**, set the **Launch Options** to the exact filename of the installer, for instance:
    ```
    RSI Launcher-Setup-2.4.0.exe
    ```
  - Under **Compatibility**, check:
    > **Force the use of a specific Steam Play compatibility tool**  
    and select the Proton version you installed earlier (GE or CachyOS).

### 5. Launch the Installer

- Start the game from Steam.
- The RSI installer will launch. When asked for installation location:
  - Choose `Z:\` → navigate to `/` → go to the folder containing `sc-launcher.sh` → select `Roberts Space Industries`.

### 6. Final Configuration

- After installation completes, **exit the installer**.
- Go back to Steam → **Properties** → **Shortcut** → **clear the Launch Options**.
- Launch the game again via Steam.

### 7. Upaating installer (If the installer does not load a newer versaion automatically)
- Download the RSI installer (`RSI Launcher-Setup-*.exe`) from the official RSI homepage into this subfolder (`Roberts Space Industries`).
- repeat steps 4 - 6.

---

## Notes

- When the game starts, you may see a warning about an untested Windows version — this is expected. Just click OK and continue.
- Enjoy playing Star Citizen on Linux!
