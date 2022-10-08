#!/usr/bin/env bash
# This file:
#
#  - This is a bash script to setup the default paramaters for a headless rpi
#
# Usage:
#
#  see help
#
# Based on a template by BASH3 Boilerplate v2.3.0
# http://bash3boilerplate.sh/#authors
#
# The MIT License (MIT)
# Copyright (c) 2013 Kevin van Zonneveld and contributors
# You are not obligated to bundle the LICENSE file with your b3bp projects as long
# as you leave these references intact in the header comments of your source files.

### BASH3 Boilerplate (b3bp) Header
##############################################################################

# Commandline options. This defines the usage page, and is used to parse cli
# opts & defaults from. The parsing is unforgiving so be precise in your syntax
# - A short option must be preset for every long option; but every short option
#   need not have a long option
# - `--` is respected as the separator between options and arguments
# - We do not bash-expand defaults, so setting '~/app' as a default will not resolve to ${HOME}.
#   you can use bash variables to work around this (so use ${HOME} instead)

# shellcheck disable=SC2034
read -r -d '' __usage <<-'EOF' || true # exits non-zero when EOF encountered
  -r --run         Run the script.
  -v               Enable verbose mode, print script as it is executed
  -d --debug       Enables debug mode
  -h --help        This page
  -n --no-color    Disable color output
EOF

# shellcheck disable=SC2034
read -r -d '' __helptext <<-'EOF' || true # exits non-zero when EOF encountered
 Do a headless setup for the rpi!
EOF

# shellcheck source=main.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/main.sh"

### Signal trapping and backtracing
##############################################################################

function __b3bp_cleanup_before_exit() {
    info "Cleaning up. Done"
}
trap __b3bp_cleanup_before_exit EXIT

# requires `set -o errtrace`
__b3bp_err_report() {
    local error_code=${?}
    # shellcheck disable=SC2154
    error "Error in ${__file} in function ${1} on line ${2}"
    exit ${error_code}
}
# Uncomment the following line for always providing an error backtrace
# trap '__b3bp_err_report "${FUNCNAME:-.}" ${LINENO}' ERR

### Command-line argument switches (like -d for debugmode, -h for showing helppage)
##############################################################################

# debug mode
if [[ "${arg_d:?}" = "1" ]]; then
    set -o xtrace
    PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    LOG_LEVEL="7"
    # Enable error backtracing
    trap '__b3bp_err_report "${FUNCNAME:-.}" ${LINENO}' ERR
fi

# verbose mode
if [[ "${arg_v:?}" = "1" ]]; then
    set -o verbose
fi

# no color mode
if [[ "${arg_n:?}" = "1" ]]; then
    NO_COLOR="true"
fi

# help mode
if [[ "${arg_h:?}" = "1" ]]; then
    # Help exists with code 1
    help "Help using ${0}"
fi

### Validation. Error out if the things required for your script are not present
##############################################################################

[[ "${arg_r:?}" == "1" ]] || help "You must use -r as it is required."
[[ "${LOG_LEVEL:-}" ]] || emergency "Cannot continue without LOG_LEVEL. "

#Check if the script is ran by root
__system_user_name=$(id -un)
if [[ "${__system_user_name}" != 'root' ]]; then
    error 'This script must be run as root.'
    exit 1
fi

__boot_config=/boot/config.txt

### Runtime
##############################################################################

__disable_ipv6() {
    info "Disabling ipv6."
    echo "net.ipv6.conf.all.disable_ipv6 = 1" | tee /etc/sysctl.d/disable-ipv6.conf >/dev/null
    echo "blacklist ipv6" | tee /etc/modprobe.d/blacklist-ipv6.conf >/dev/null
}

__disable_audio() {
    info "Disabling Audio."
    sed -i '/dtparam=audio/c dtparam=audio=off' $__boot_config
}
__disable_bluetooth() {
    info "Disabling Bluetooth."
    __dtoverlay_entry disable-bt
    __stop_and_mask bluetooth
    # Remove bluetooth dependencies
    apt-get purge bluez piwiz -y -qq >/dev/null
    apt-get autoremove --purge -y -qq >/dev/null
}

__disable_wifi() {
    info "Disabling WiFi."
    __dtoverlay_entry disable-wifi
    __stop_and_mask wpa_supplicant hciuart
}

__dtoverlay_entry() {
    if ! grep -q "dtoverlay=$1" $__boot_config; then
        echo "dtoverlay=$1" | tee -a $__boot_config >/dev/null
    fi
}

__stop_and_mask() {
    systemctl stop "$@"
    systemctl mask "$@"
}
__update_apt() {
    info "Updating the apt packages."
    apt-get update >/dev/null
    apt-get -y upgrade -qq >/dev/null

}
__execute_raspi_config() {
    info "Updating the raspi-config settings."
    grep -E -v -e '^\s*#' -e '^\s*$' <<END |
\
# Hardware Configuration
do_boot_wait 0            # Turn off waiting for network before booting
do_boot_splash 1          # Disable the splash screen
do_overscan 1             # Disable overscan
do_camera 1               # Disable the camera
do_spi 1                  # Disable spi bus
do_memory_split 16        # Set the GPU memory limit to 16MB
do_i2c 1                  # Disable the i2c bus
do_serial 1               # Disable the RS232 serial bus

# System Configuration (For Eastern Time in the United States!)
do_change_timezone America/New_York
do_change_locale en_US.UTF-8

# Don't add any raspi-config configuration options after 'END' line below & don't remove 'END' line
END
        sed -e 's/$//' -e 's/^\s*/\/usr\/bin\/raspi-config nonint /' | bash -

}

headless_config() {
    __update_apt
    # Disable Stuff
    __disable_audio
    __disable_ipv6
    __disable_bluetooth
    __disable_wifi
    __execute_raspi_config
    __stop_and_mask ModemManager.service

    warning "Rebooting in 5 seconds"
    sleep 5
    reboot
}

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f headless_config
else
    headless_config "${@}"
    exit ${?}
fi
