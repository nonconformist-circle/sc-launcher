#!/bin/bash
## =========================================================================================
## 
## * This script works with ProtonQT/ProtonUP, and does not always work with ProtonPlus 
## because ProtonPlus does not follow Steam naming conventions that this script relies on.
##
## * For custom setting place a file named sc-launcher.env in same directory as this script.
## see sc-launcher.env.template
##
## =========================================================================================
wdir=$(dirname $(readlink -f $0))

# Settings
STEAM_CLIENT_APP_ID=${STEAM_CLIENT_APP_ID:-"${STEAM_COMPAT_DATA_PATH##*/}"}
RSI_LAUNCHER="RSI Launcher.exe"
STEAM_CLIENT_CONFIG=$HOME/.steam/steam/config/config.vdf
GAME_INSTALLATION_FOLDER=${wdir}
STEAM_ZENITY=/usr/bin/zenity

## =========================================================================================
##  Load custom environment
## =========================================================================================
[ -f ${wdir}/sc-launcher.env ] && source ${wdir}/sc-launcher.env

if [[ "${SteamClientLaunch}" != "1" ]] && [ -z "${STEAM_CLIENT_APP_ID}" ]; then
  dump_env
  echo "ERROR: Could not determine STEAM_CLIENT_APP_ID. Exiting." | tee >&2
  exit 1
fi

## =========================================================================================
## Functions
## =========================================================================================
dump_env() {
  # Little debug (use journalctl -f)
  echo -e "
# [ ------------------- BOF DEBUG ------------------- ]

# Launcher settings
RSI_INSTALLER_PATH="${RSI_INSTALLER_PATH}"
RSI_LAUNCHER="${RSI_LAUNCHER}"

# Steam environment
STEAM_CLIENT_APP_ID=${STEAM_CLIENT_APP_ID}
STEAM_COMPAT_DATA_PATH=${STEAM_COMPAT_DATA_PATH}
STEAM_COMPAT_CLIENT_INSTALL_PATH=${STEAM_COMPAT_CLIENT_INSTALL_PATH}
STEAM_COMPAT_TRANSCODED_MEDIA_PATH=${STEAM_COMPAT_TRANSCODED_MEDIA_PATH}

# Proton environment
PROTON_PATH=${PROTON_PATH}
PROTON_PREFIX_VERSION=${PROTON_PREFIX_VERSION}
PROTON_VERSION=${PROTON_VERSION}
WINEPREFIX=${WINEPREFIX}

# App
APP_PATH=${APP_PATH}

# Steam env
$(env | grep -iE '(steam)')

# [ ------------------- EOF DEBUG ------------------- ]
" | tee >&2
}

version_to_int() {
  IFS=. read -r major minor patch <<< "$1"
  major=${major:-0}
  minor=${minor:-0}
  patch=${patch:-0}
  echo $(( major * 10000 + minor * 100 + patch ))
}

get_proton_flavor() {
  local IFS=:
  for path in $STEAM_COMPAT_TOOL_PATHS; do 
    [[ "$path" == "$STEAM_BASE_FOLDER"/compatibilitytools.d/* ]] && echo "$path" && break
  done
}

get_rsi_setup_versions() {
  currentInstallerVersion=$(find ${STEAM_COMPAT_DATA_PATH} -type f -name 'RSI Launcher-Setup*.exe' | grep -oE "[0-9]\.[0-9]\.[0-9]" | sort -h | tail -n1)
  newInstallerLink=$(curl -s https://robertsspaceindustries.com/en/download | grep downloadLink | grep -oE 'https://install.robertsspaceindustries.com[^\"]+')
  newInstallerVersion=$(echo ${newInstallerLink} | grep -oE "[0-9]\.[0-9]\.[0-9]" )
  newInstallerExe=${newInstallerLink##*/}
}

## =========================================================================================
## Steam libs and Proton prefix location
## =========================================================================================
export STEAM_COMPAT_CLIENT_INSTALL_PATH=${STEAM_BASE_FOLDER:-"${HOME}/.steam/debian-installation"}
export STEAM_COMPAT_DATA_PATH=${GAME_INSTALLATION_FOLDER:-"${STEAM_COMPAT_CLIENT_INSTALL_PATH}/steamapps/compatdata/${STEAM_CLIENT_APP_ID}"}
export WINEPREFIX="${STEAM_COMPAT_DATA_PATH}/pfx"

if [[ ! "${@}" =~ noupgrade ]]; then
  get_rsi_setup_versions
  if [ $(version_to_int "${newInstallerVersion}") -gt $(version_to_int "${currentInstallerVersion}") ]; then
    if "${STEAM_ZENITY}" --question --title="SC-Launcher.sh" --text="There is a new launcher version ${newInstallerVersion}, do you want to insall now?"; then
        echo "Downloading installer" | tee >&2
        RSI_INSTALLER_PATH=${STEAM_COMPAT_DATA_PATH}/$(printf '%b' "${newInstallerExe//%/\\x}")
        curl -o "${RSI_INSTALLER_PATH}" "${newInstallerLink}"
    fi
  fi
fi

if [ ! -z "${RSI_INSTALLER_PATH}" ]; then
  # Launch the RSI Launcher setup using Proton
  APP_PATH=${RSI_INSTALLER_PATH}
else
  # Launch the RSI Launcher using Proton
  APP_PATH=$(find ${STEAM_COMPAT_DATA_PATH} -type f -name "${RSI_LAUNCHER}")
  if [ -z "${APP_PATH}" ]; then
    dump_env
    echo "ERROR: Star Citizen not yet installed. Need RSI installer file name (quoted) as parameter" >&2
    exit 1
  fi
fi

## =========================================================================================
## Ensure paths
## =========================================================================================
mkdir -p ${HOME}/.config/protonfixes ${STEAM_COMPAT_DATA_PATH}

## =========================================================================================
## Get Proton flavor and version set in Steam
## =========================================================================================
PROTON_PATH=${PROTON_FLAVOR:-"$(get_proton_flavor)"}/proton
if [ ! -f "${PROTON_PATH}" ]; then
  dump_env
  echo "ERROR: Could not determine PROTON_PATH. Exiting." >&2
  exit 1
fi

## =========================================================================================
## Ensure proton envs if needed
## =========================================================================================
if declare -F proton_envs > /dev/null; then
  PROTON_PREFIX_VERSION=$(grep -roE 'CURRENT_PREFIX_VERSION="[^"]+"' "${PROTON_PATH}" | grep -oE '[^"]+' | tail -n1)
  PROTON_VERSION=$(echo "${PROTON_PREFIX_VERSION}" | grep -oE '[0-9]+' | head -n1)
  [ ! -z "${PROTON_VERSION}"] && proton_envs
fi

## =========================================================================================
## Launch game
## =========================================================================================
dump_env
exec "${PROTON_PATH}" run "${APP_PATH}"

