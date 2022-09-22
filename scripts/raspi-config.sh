#!/bin/sh
#
# Don't change the following lines unless you know what you are doing
# They execute the config options starting with 'do_' below
grep -E -v -e '^\s*#' -e '^\s*$' <<END |
\
# Hardware Configuration
do_boot_wait 0            # Turn off waiting for network before booting
do_boot_splash 1          # Disable the splash screen
do_overscan 1             # Disable overscan
do_camera 1               # Disable the camera
do_spi 1                  # Disable spi bus
do_memory_split 16        # Set the GPU memory limit to 64MB
do_i2c 1                  # Disable the i2c bus
do_serial 1               # Disable the RS232 serial bus

# System Configuration
do_change_timezone America/New_York
do_change_locale en_US.UTF-8

#Don't add any raspi-config configuration options after 'END' line below & don't remove 'END' line
END
    sed -e 's/$//' -e 's/^\s*/\/usr\/bin\/raspi-config nonint /' | bash -x -

############# CUSTOM COMMANDS ###########
# You may add your own custom GNU/Linux commands below this line
# These commands will execute as the root user

# Some examples - uncomment by removing '#' in front to test/experiment
sudo systemctl disable wpa_supplicant && sudo systemctl disable bluetooth && sudo systemctl disable hciuart && sudo systemctl disable ModemManager.service
#/usr/bin/raspi-config do_wifi_ssid_passphrase # Interactively configure the wifi network

#/usr/bin/aptitude update                      # Update the software package information
#/usr/bin/aptitude upgrade                     # Upgrade installed software to the latest versions

#/usr/bin/raspi-config do_change_pass          # Interactively set password for your login

/sbin/shutdown -r now # Reboot after all changes above complete
