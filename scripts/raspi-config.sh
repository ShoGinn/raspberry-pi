#!/usr/bin/env bash
#
CONFIG=/boot/config.txt
spinner_pid=

disable_bluetooth() {
    dtoverlay_entry disable-bt
    stop_and_mask bluetooth
    # Remove bluetooth dependencies
    sudo apt-get purge bluez piwiz -y -qq >/dev/null
    sudo apt-get autoremove --purge -y -qq >/dev/null

}
disable_wifi() {
    dtoverlay_entry disable-wifi
    stop_and_mask wpa_supplicant hciuart

}
dtoverlay_entry() {
    if ! grep -q "dtoverlay=$1" $CONFIG; then
        echo "dtoverlay=$1" | sudo tee -a $CONFIG >/dev/null
    fi

}
stop_and_mask() {
    sudo systemctl stop "$@"
    sudo systemctl mask "$@"
}
execute_raspi_config() {
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
        sed -e 's/$//' -e 's/^\s*/\/usr\/bin\/raspi-config nonint /' | sudo bash -

}

function start_spinner {
    set +m
    echo -n "$1         "
    { while :; do for X in '  •     ' '   •    ' '    •   ' '     •  ' '      • ' '     •  ' '    •   ' '   •    ' '  •     ' ' •      '; do
        echo -en "\b\b\b\b\b\b\b\b$X"
        sleep 0.1
    done; done & } 2>/dev/null
    spinner_pid=$!
}

function stop_spinner {
    { kill -9 $spinner_pid && wait; } 2>/dev/null
    set -m
    echo -en "\033[2K\r"
}

trap stop_spinner EXIT

lsb_release -ds
start_spinner "Updating apt. This could take a while ..."
(
    sudo apt-get update >/dev/null
    wait
    sudo apt-get -y upgrade -qq >/dev/null
)
stop_spinner
wait
# Disable Stuff
start_spinner "Disabling Bluetooth, WiFi and setting Locales"
disable_bluetooth
disable_wifi
execute_raspi_config
stop_and_mask ModemManager.service
stop_spinner

start_spinner "Rebooting in 5 seconds"
sleep 5
sudo reboot
