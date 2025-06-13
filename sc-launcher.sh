#!/bin/bash

# Settings
STEAM_CLIENT_APP_ID=${STEAM_COMPAT_TRANSCODED_MEDIA_PATH##*/}
GAME_INSTALLATION_FOLDER=/mnt/games/star-citizen/
RSI_INSTALLER=${1}
RSI_LAUNCHER="RSI Launcher.exe"
RSI_LAUNCHER_PATH="RSI Launcher"
STEAM_CLIENT_CONFIG=$HOME/.steam/steam/config/config.vdf

# get Proton you set in Steam (or ProtonQT set)
PROTON_FLAVOR=$(grep -A3 $STEAM_CLIENT_APP_ID $STEAM_CLIENT_CONFIG | grep name | grep -ioE '[^"]*proton.*[^"]+')
if [ ! -z "${PROTON_FLAVOR}" ]; then
  PROTON_BIN="$(readlink -f $HOME/.steam/root/compatibilitytools.d/$PROTON_FLAVOR)/proton"
else
  PROTON_BIN="proton"
fi

# little debug
echo -e "
STEAM_CLIENT_APP_ID=${STEAM_CLIENT_APP_ID}
PROTON_FLAVOR=${PROTON_FLAVOR}
PROTON_BIN=${PROTON_BIN}
" >&2

# Proton prefix location 
export STEAM_COMPAT_CLIENT_INSTALL_PATH="${HOME}/.steam/debian-installation"
export STEAM_COMPAT_DATA_PATH="${STEAM_COMPAT_CLIENT_INSTALL_PATH}/steamapps/compatdata/${STEAM_CLIENT_APP_ID}/"
export WINEPREFIX="${STEAM_COMPAT_DATA_PATH}/pfx"

# Proton performance env vars
export PROTON_NO_ESYNC=1
export PROTON_NO_FSYNC=1
export DXVK_ASYNC=1

# HUD for debugging and gpu info (for ingame FPS use Steam client settings)
#export DXVK_HUD=0 #Options: api,fps,frametime,devinfo,gpuload,version
#export DXVK_HUD_FONT_SCALE=0.5
#export DXVK_HUD_POSITION=top-left #Options: top-left (default), top-right, bottom-left, bottom-right

# Logging
export DXVK_LOG_LEVEL=debug

# Navigate to RSI Launcher directory
cd "${GAME_INSTALLATION_FOLDER}/Roberts Space Industries/"

# Optional: dummy steam_appid.txt for Steam API compatibility
echo 480 > steam_appid.txt

if [ ! -z "${RSI_INSTALLER}" ]; then
  # Launch the RSI Launcher setup using Proton
  exec "${PROTON_BIN}" run "${RSI_INSTALLER}"
else
  # Launch the RSI Launcher using Proton
  cd "${RSI_LAUNCHER_PATH}"
  exec "${PROTON_BIN}" run "${RSI_LAUNCHER}"
fi
