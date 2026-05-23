#!/usr/bin/env bash

install_script_path="$(printf "%s\n" "$0" | rev | cut -d/ -f2- | rev)"
le_script_name="check-letsencrypt-certs"
destination="/etc/letsencrypt/scripts"

link="false"
if [[ "$1" == "--link" ]]; then
    link="true"
fi

sudo=""
if [[ "$(id -u)" != "0" ]]; then
    sudo="sudo "
fi

printf "%s\n" ""
printf "%b\n" "Installing \e[38;5;33mBlueKnight\e[0m's $le_script_name script"

if [[ ! -d "$destination" ]]; then
  if ! ${sudo}mkdir --parents --verbose "$destination"; then
    printf "%b\n" "\e[38;5;160mError 1\e[0m: Failed to make $destination"
    exit 1
  fi
fi

if [[ ! -f "${install_script_path}/${le_script_name}.sh" ]]; then
    printf "%b\n" "\e[38;5;160mError 2\e[0m: can not locate script in the installer's directory."
    exit 2
fi

if [[ "$link" == "true" ]]; then
  printf "%s\n" "Linking ${destination}/${le_script_name}.sh to local file."
  if ! ${sudo}ln --symbolic --verbose "${PWD}/${le_script_name}.sh" "${destination}/${le_script_name}.sh"; then
    printf "%s\n" "Unable to set the link at ${destination}/${le_script_name}.sh"
    exit 3
  fi
else
  printf "%s\n" "Copying script to ${destination}"
  if ! ${sudo}cp --update --verbose "${install_script_path}/${le_script_name}.sh" "${destination}"; then
    printf "%s\n" "Unable to copy ${install_script_path}/${le_script_name}.sh to destination directory ${destination}"
    exit 4
  fi
fi

printf "%b\n" "-- \e[38;5;40mInstall Complete\e[0m --"
printf "%s\n" ""
exit 0
