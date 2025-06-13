# sc-launcher
**Play Star Citizen on Linux**

## Overview

This script helps you install and run the *Star Citizen* launcher on Linux using Proton via Steam.

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
