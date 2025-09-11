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
wdir=$(dirname $(readlink -f $0))

## =========================================================================================
## Default Settings
## =========================================================================================
STEAM_CLIENT_APP_ID=${STEAM_CLIENT_APP_ID:-"${STEAM_COMPAT_DATA_PATH##*/}"}
RSI_LAUNCHER="RSI Launcher.exe"
STEAM_ZENITY=${STEAM_ZENITY:-"/usr/bin/zenity"}
CURL_OPTS=(-fL --retry 5 --retry-delay 2 --connect-timeout 10 --continue-at -)
DUMP_STEAM_EVNIRONMENT=false

## =========================================================================================
## Functions
## =========================================================================================
on_err() {
  local status=$? line=$1 cmd=$2 src=$3
  echo -e "ERROR: Function ${src} failed (exit=${status}) at line ${line}: ${cmd}" | tee ${CUSTOM_LOG_FILE_TEE} >&2
}
trap 'on_err "$LINENO" "$BASH_COMMAND" "${FUNCNAME[0]:-MAIN}"' ERR

raise_error() {
  local message=$@
  dump_env
  echo -e "ERROR: ${message}"  | tee ${CUSTOM_LOG_FILE_TEE} >&2
  exit 1
}

log_info() {
  local message=$@
  err "INFO: ${message}"  | tee ${CUSTOM_LOG_FILE_TEE} >&2
  dump_env
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

# Logging
CUSTOM_LOG_FILE=${CUSTOM_LOG_FILE}

# RSI Installer
currentInstallerVersion=${currentInstallerVersion}
newInstallerLink=${newInstallerLink}
newInstallerVersion=${newInstallerVersion}

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
    && currentInstallerVersion=$(grep -Po '(?<=DisplayName"="RSI Launcher )[^"]*' ${WINEPREFIX}/system.reg) \
    || currentInstallerVersion="0.0.0"
  # check version available on RSI webside
  newInstallerLink=$(curl "${CURL_OPTS[@]}" -s https://robertsspaceindustries.com/en/download | grep downloadLink | grep -oE 'https://install.robertsspaceindustries.com[^\"]+')
  newInstallerVersion=$(echo ${newInstallerLink} | grep -oE "[0-9]\.[0-9]\.[0-9]" )
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

## =========================================================================================
##  Load custom environment
## =========================================================================================
[ -f ${wdir}/sc-launcher.env ] && source ${wdir}/sc-launcher.env

## =========================================================================================
##  Load steam environment
## =========================================================================================
[ -z "${STEAM_BASE_FOLDER}" ] && export STEAM_BASE_FOLDER="${HOME}/.steam/debian-installation" || export STEAM_BASE_FOLDER=${STEAM_BASE_FOLDER}
export STEAM_COMPAT_CLIENT_INSTALL_PATH=${STEAM_BASE_FOLDER}
export STEAM_COMPAT_DATA_PATH=${STEAM_COMPAT_DATA_PATH:-"${STEAM_COMPAT_CLIENT_INSTALL_PATH}/steamapps/compatdata/${STEAM_CLIENT_APP_ID}"}
export WINEPREFIX="${STEAM_COMPAT_DATA_PATH}/pfx"
[ ${STEAM_COMPAT_PROTON:-0} -eq 0 ] && isSteamScopeMissing=true || isSteamScopeMissing=false
CUSTOM_LOG_FILE_TEE=""

## =========================================================================================
## Check steam environment
## =========================================================================================
if [ -z "${STEAM_CLIENT_APP_ID}" ]; then
  ${isSteamScopeMissing} \
  && errorMsg="Could not determine STEAM_CLIENT_APP_ID, you" \
  || errorMsg="Could not determine STEAM_CLIENT_APP_ID. Exiting."
  raise_error "${errorMsg}"
fi

if [ ! -d  "${STEAM_BASE_FOLDER}" ]; then
  ${isSteamScopeMissing} \
  && errorMsg="Expected STEAM_BASE_FOLDER does not exists at ${STEAM_BASE_FOLDER},
you run this script form outside steam scope, make sure that STEAM_BASE_FOLDER in sc-launcher.env, usually ~/.steam/debian-installation" \
  || errorMsg="Expected STEAM_BASE_FOLDER does not exists at ${STEAM_BASE_FOLDER}, check your stean installation" 
  raise_error "${errorMsg}"
fi

if [ -z "${STEAM_COMPAT_DATA_PATH}" ]; then
  ${isSteamScopeMissing} \
  && errorMsg="Steam env STEAM_COMPAT_DATA_PATH is empty. You are run this script outside steam scope, make sure that:
1. you deficne STEAM_COMPAT_DATA_PATH in sc-launcher.env,
2. you are aware this migh end up in two differen prefix location. The steam default is like ~/.steam/debian-installation/steamapps/compatdata/<STEAM_CLIENT_APP_ID>,
3. you know what you are doing." \
  || errorMsg="Steam env STEAM_COMPAT_DATA_PATH is empty, that should not happen. Check your Steam installation"
  raise_error "${errorMsg}"
fi

## =========================================================================================
## Install/Update the RSI Launcher Setup.exe
## =========================================================================================
[[ ! "${@}" =~ noupgrade ]] && check_and_download_rsi_setup || log_info "Installation/Updades prohobitet by parameter 'noupgrade'."

if [ ! -z "${RSI_INSTALLER_PATH}" ]; then
  APP_PATH=${RSI_INSTALLER_PATH}
elif [ ! -z "${STEAM_COMPAT_DATA_PATH}" ]; then
  APP_PATH=$(find ${STEAM_COMPAT_DATA_PATH} -type f -name "${RSI_LAUNCHER}")
fi

if [ -z "${APP_PATH}" ]; then
  raise_error "RSI Launcher.exe not found in tree ${STEAM_COMPAT_DATA_PATH}. Star Citizen is not yet installed in the prefix ${WINEPREFIX}. 
Need RSI installer file path as env RSI_INSTALLER_PATH in sc-launcher.env if you don't allow to download it by script." 
fi 

## =========================================================================================
## Ensure log and paths
## =========================================================================================
[ ! -z "${CUSTOM_LOG_FILE}" ] && handle_custom_log_file
mkdir -p ${HOME}/.config/protonfixes ${STEAM_COMPAT_DATA_PATH}

## =========================================================================================
## Get Proton flavor and version set in Steam
## =========================================================================================
PROTON_PATH=${PROTON_FLAVOR:-"$(get_proton_flavor)"}/proton
if [ ! -f "${PROTON_PATH}" ]; then
  raise_error "Could not determine PROTON_PATH. If you run the script from cli make sure to add env PROTON_FLAVOR in sc-launcher.env pointing to ${STEAM_BASE_FOLDER}/compatibilitytools.d/Proton-runner-dir-of-your-choise"
fi

## =========================================================================================
## Ensure proton envs if needed
## =========================================================================================
if declare -F proton_envs > /dev/null; then
  PROTON_PREFIX_VERSION=$(grep -roE 'CURRENT_PREFIX_VERSION="[^"]+"' "${PROTON_PATH}" | grep -oE '[^"]+' | tail -n1)
  PROTON_VERSION=$(echo "${PROTON_PREFIX_VERSION}" | grep -oE '[0-9]+' | head -n1)
  proton_envs
fi

## =========================================================================================
## Launch game
## =========================================================================================
dump_env
exec "${PROTON_PATH}" run "${APP_PATH}"

