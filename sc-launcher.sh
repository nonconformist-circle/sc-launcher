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
set -E -o pipefail
wdir=$(dirname $(readlink -f "$0"))

## =========================================================================================
## Default Settings
## =========================================================================================
RSI_LAUNCHER="RSI Launcher.exe"
STEAM_ZENITY=${STEAM_ZENITY:-"/usr/bin/zenity"}
CURL_OPTS=(-fL --retry 5 --retry-delay 2 --connect-timeout 10 --continue-at -)
DUMP_STEAM_EVNIRONMENT=false
PATCH_GAME_SETUP_GRAPHICS_API=true

## Vulkan / runtime hardening
USE_VULKAN=${USE_VULKAN:-true}

CUSTOM_LOG_FILE_TEE="/dev/null"
APP_PATH_ARGS=""
## =========================================================================================
## Functions
## =========================================================================================
warn() { echo -e "WARN: $*" | tee ${CUSTOM_LOG_FILE_TEE} >/dev/stderr; }
info() { echo -e "INFO: $*" | tee ${CUSTOM_LOG_FILE_TEE} >/dev/stderr; }

on_err() {
  local status=$? line=$1 cmd=$2 src=$3
  echo -e "ERROR: Function ${src} failed (exit=${status}) at line ${line}: ${cmd}" | tee ${CUSTOM_LOG_FILE_TEE} >&2
}
trap 'on_err "$LINENO" "$BASH_COMMAND" "${FUNCNAME[0]:-MAIN}"' ERR

raise_error() {
  local errorMsg="${*}"
  set +e
  trap - ERR
  dump_env || true
  echo -e "ERROR: ${errorMsg}" >&2
  [ -n "${CUSTOM_LOG_FILE_TEE}" ] && echo -e "ERROR: ${errorMsg}" | tee ${CUSTOM_LOG_FILE_TEE} >&2 || true
  "${STEAM_ZENITY}" --error --title="sc-launcher.sh" --text="${errorMsg}"
  exit 1
}

abort_info() {
  set +e
  trap - ERR
  echo -e "INFO: $*" | tee ${CUSTOM_LOG_FILE_TEE} >&2
  dump_env || true
  "${STEAM_ZENITY}" --info --title="sc-launcher.sh" --text="${errorMsg}"
  exit 1
}

dump_env() {
  # Little debug (use journalctl -fu steam)
  echo -e "
# [ ------------------- BOF DUMP ------------------- ]

# Launcher settings
RSI_INSTALLER_PATH="${RSI_INSTALLER_PATH}"
RSI_LAUNCHER="${RSI_LAUNCHER}"

# Steam environment
## Local
STEAM_BASE_FOLDER=${STEAM_BASE_FOLDER}
STEAM_COMPAT_DATA_PATH=${STEAM_COMPAT_DATA_PATH}
## Exported
$(env | grep -E '^STEAM_.*$' | sort -h)

# Proton environment
## Local
STEAM_RUNNNER=${STEAM_RUNNNER}
PROTON_PATH=${PROTON_PATH}
PROTON_PREFIX_VERSION=${PROTON_PREFIX_VERSION}
PROTON_VERSION=${PROTON_VERSION}
WINEPREFIX=${WINEPREFIX}
## Exported
$(env | grep -E '^PROTON.*$' | sort -h)
$(env | grep -E '^WINE.*$' | sort -h)

# App
APP_PATH=${APP_PATH}
APP_PATH_ARGS=${APP_PATH_ARGS}

# Logging
CUSTOM_LOG_FILE=${CUSTOM_LOG_FILE}

# RSI Installer
currentInstallerVersion=${currentInstallerVersion}
newInstallerLink=${newInstallerLink}
newInstallerVersion=${newInstallerVersion}

# VULKAN
## Local
USE_VULKAN=${USE_VULKAN}
VULKAN_PREFLIGHT=${VULKAN_PREFLIGHT}
## Exported
$(env | grep -E '^VK_.*$' | sort -h)
$(env | grep -E '_VK_' | sort -h)

# [ ------------------- EOF DUMP ------------------- ]
" | tee ${CUSTOM_LOG_FILE_TEE} >&2

${DUMP_STEAM_EVNIRONMENT} && echo -e "
# [ ------------------- BOF STEAM ENVIRONMENT DUMP ------------------- ]

# Dump all Steam envs
$(env | grep -iE '(steam)')

# [ ------------------- EOF STEAM ENVIRONMENT DUMP ------------------- ]
" | tee ${CUSTOM_LOG_FILE_TEE} >&2 || true
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
  for path in ${STEAM_COMPAT_TOOL_PATHS:-"${PATH}"}; do 
    [[ "$path" == "$STEAM_BASE_FOLDER"/compatibilitytools.d/* ]] && echo "$path" | grep -oE "${STEAM_BASE_FOLDER}/compatibilitytools.d/[^/]+" && break || true
  done
}

check_and_download_rsi_setup() {
  # check if registry is available to read out the current launcher version
  [ -f "${WINEPREFIX}/system.reg" ] \
    && currentInstallerVersion=$(grep -Po '(?<=DisplayName"="RSI Launcher )[^"]*' "${WINEPREFIX}/system.reg") \
    || currentInstallerVersion="0.0.0"
  # check version available on RSI webside
  newInstallerLink=$(curl "${CURL_OPTS[@]}" -s https://robertsspaceindustries.com/en/download | grep downloadLink | grep -oE 'https://install.robertsspaceindustries.com[^\"]+')
  newInstallerVersion=$(echo ${newInstallerLink} | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" )
  local newInstallerExe=${newInstallerLink##*/}
  # compare versions  
  if [ $(version_to_int "${newInstallerVersion}") -gt $(version_to_int "${currentInstallerVersion}") ]; then
    # prepare message context
    [[ "${currentInstallerVersion}" == "0.0.0" ]] \
      && msgText="Need to install the game using the RSI laucher ${newInstallerVersion}" \
      || msgText="There is a new RSI launcher version ${newInstallerVersion}"
    # create question form
    if "${STEAM_ZENITY}" --question --no-wrap --title="sc-launcher.sh" --text="${msgText}, do you want to insall now?"; then
        echo "INFO: Downloading installer..." | tee ${CUSTOM_LOG_FILE_TEE} >&2
        RSI_INSTALLER_PATH=${STEAM_COMPAT_DATA_PATH}/$(printf '%b' "${newInstallerExe//%/\\x}")
        curl "${CURL_OPTS[@]}" --output "${RSI_INSTALLER_PATH}" "${newInstallerLink}"
        echo "INFO: done."
    fi
  fi
}

handle_custom_log_file() {
  if [ -f "${CUSTOM_LOG_FILE}" ]; then
    truncate -s 0 ${CUSTOM_LOG_FILE}
  else
    touch ${CUSTOM_LOG_FILE} || raise_error "Unable to create custom log file at ${CUSTOM_LOG_FILE}"
  fi
  CUSTOM_LOG_FILE_TEE="-a ${CUSTOM_LOG_FILE}"
}

vulkan_preflight() {
  info "Vulkan preflight: host visibility check"

  if command -v ldconfig >/dev/null 2>&1; then
    local x64 i386
    x64=$(ldconfig -p 2>/dev/null | grep -E 'libvulkan\.so\.1.*x86-64' || true)
    i386=$(ldconfig -p 2>/dev/null | grep -E 'libvulkan\.so\.1.*i386' || true)

    [ -n "$x64" ] && info "Found 64-bit Vulkan loader via ldconfig" || warn "Missing 64-bit Vulkan loader (libvulkan.so.1 x86-64)"
    [ -n "$i386" ] && info "Found 32-bit Vulkan loader via ldconfig" || warn "Missing 32-bit Vulkan loader (libvulkan.so.1 i386) — common Proton Vulkan blocker"
  fi

  if command -v vulkaninfo >/dev/null 2>&1; then
    vulkaninfo --summary 2>/dev/null | tee ${CUSTOM_LOG_FILE_TEE} >&2 || true
  else
    warn "vulkaninfo not found (package typically: vulkan-tools). Skipping vulkaninfo summary."
  fi
}

patch_game_config() {
  if ! ${PATCH_GAME_SETUP_GRAPHICS_API}; then
    info "GraphicsSettings patching disabled"
    return 0
  fi
  local useVulkan=${1:-true}
  ${useVulkan} && {
    swA=0
    swB=1
    info "GraphicsSettings set to Vulkan"
  } || {
    # DX
    swA=1
    swB=0
    info "GraphicsSettings set to DirectX"
  }
  find "${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/users/steamuser/AppData/Local/star citizen/" -type f -name 'GraphicsSettings.json' | xargs -I{} sed -i'.bck' 's#"GraphicsRenderer": '${swA}'#"GraphicsRenderer": '${swB}'#g' "{}"
}

##=========================================================================================
## prefix patches
##=========================================================================================
## patch for MSVCP140.dll issue on Star Citizen v4.7 and vulkan black screen issues
## see sc-launcher.env -> apply_vcrun2022_workaround
apply_vcrun2022_workaround() {
  local prefix="${STEAM_COMPAT_DATA_PATH}/pfx"
  local wine_bin="$(dirname "${PROTON_PATH}")/files/bin/wine"

  [ -d "${prefix}" ] || return 1
  [ -n "${wine_bin}" ] || return 1
  [ -x "${wine_bin}" ] || return 1

  if "${wine_bin}" reg query 'HKCU\Software\Wine\DllOverrides' /v msvcp140 2>/dev/null | grep -q 'native,builtin'; then
    echo "vcrun2022/native MSVC runtime already present, skipping"
    return 0
  fi

  env WINEPREFIX="${prefix}" WINE="${wine_bin}" winetricks -q vcrun2022
}

## =========================================================================================
## Get Proton flavor and version set in Steam
## =========================================================================================
PROTON_PATH=${PROTON_FLAVOR:-"$(get_proton_flavor)"}/proton
if [ ! -f "${PROTON_PATH}" ]; then
  errorMsg="Could not determine PROTON_PATH. Make sure Proton GE, or Proton CachyOS is installed and compatibility enforced in steam or add env PROTON_FLAVOR in sc-launcher.env pointing to ${STEAM_BASE_FOLDER}/compatibilitytools.d/Proton-runner-dir-of-your-choise"
  raise_error "${errorMsg}"
fi


## =========================================================================================
##  Load custom environment
## =========================================================================================
[ -f "${wdir}/sc-launcher.env" ] && source "${wdir}/sc-launcher.env"

VULKAN_PREFLIGHT=${VULKAN_PREFLIGHT:-"${USE_VULKAN}"}

## =========================================================================================
## Ensure steam environment
## =========================================================================================
if [ ! -d  "${STEAM_BASE_FOLDER}" ]; then
  errorMsg="Expected STEAM_BASE_FOLDER does not exists at ${STEAM_BASE_FOLDER}, check your stean installation" 
  raise_error "${errorMsg}"
fi

if [ -z "${STEAM_COMPAT_DATA_PATH}" ]; then
  errorMsg="Steam env STEAM_COMPAT_DATA_PATH is empty, that should not happen. Check your Steam installation"
  raise_error "${errorMsg}"
fi

export WINEPREFIX="${STEAM_COMPAT_DATA_PATH}/pfx"


## =========================================================================================
## Ensure log and paths
## =========================================================================================
[ ! -z "${CUSTOM_LOG_FILE}" ] && handle_custom_log_file
mkdir -p "${HOME}/.config/protonfixes" "${STEAM_COMPAT_DATA_PATH}"

# Windows ACL don't work with Proton, so we have to install the game files in Z:/../here
mkdir -p "${wdir}/gamefiles/StarCitizen/"{LIVE,PTU,HOTFIX,TECH_PREVIEW,TECHPREVIEW}

# Clean up potential EasyAntiCheat cache causing game to abort claiming a login issue after switching proton flavor
[ -d "${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/users/steamuser/AppData/Roaming/EasyAntiCheat" ]  && rm -rf ${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/users/steamuser/AppData/Roaming/EasyAntiCheat/*

## =========================================================================================
## Install/Update the RSI Launcher Setup.exe
## =========================================================================================
[[ ! "${@}" =~ noupgrade ]] && check_and_download_rsi_setup || info "Installation/Updades prohobitet by parameter 'noupgrade'."

if [ ! -z "${RSI_INSTALLER_PATH}" ]; then
  APP_PATH="${RSI_INSTALLER_PATH}"
elif [ ! -z "${STEAM_COMPAT_DATA_PATH}" ]; then
  APP_PATH=$(find "${STEAM_COMPAT_DATA_PATH}" -type f -name "${RSI_LAUNCHER}")
fi

if [ -z "${APP_PATH}" ]; then
  raise_error "RSI Launcher.exe not found in tree ${STEAM_COMPAT_DATA_PATH}. Star Citizen is not yet installed in the prefix ${WINEPREFIX}. 
Need RSI installer file path as env RSI_INSTALLER_PATH in sc-launcher.env if you don't allow to download it by script." 
fi 

## =========================================================================================
## Launch game
## =========================================================================================
patch_game_config ${USE_VULKAN}
${VULKAN_PREFLIGHT} && vulkan_preflight || true

dump_env
info "Launching ${PROTON_PATH} run ${APP_PATH} ${APP_PATH_ARGS}"
exec "${PROTON_PATH}" run "${APP_PATH}" ${APP_PATH_ARGS}

