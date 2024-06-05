#!/bin/bash
# Installer by thcrt
# Licensed under the MIT license
set -eu
IFS=$'\n\t'



# Temporary working directory
TEMP_DIR="${HOME}/.tmp/microsocks"
# Path of executable once installed
BIN_PATH="${HOME}/.local/bin/microsocks"
# Port to listen on
PORT=$(comm -23 <(seq 10000 20000 | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1)
# Password to connect with
PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
# Service file location
SERVICE_PATH="$HOME/.config/systemd/user/microsocks.service"



function _install() {
    # Give a warning
    echo "### WARNING ########################################################################################"
    echo "#                                                                                                  #"
    echo "#   The application you're about to install is unsupported by your hosting provider! Support,      #"
    echo "#   functionality, and security aren't guaranteed and will be entirely your own responsibility.    #"
    echo "#   You should only proceed with this installation if you know what you're doing.                  #"
    echo "#                                                                                                  #"
    echo "#                                                                                                  #"
    echo "#                Type 'yes' and press enter if you understand and wish to continue.                #"
    echo "#                                                                                                  #"
    echo "####################################################################################################"
    read -r -p "=> "
    echo ""
    if ! [[ $REPLY =~ "yes" ]]; then
        echo "Exiting installation!"
        exit 1
    else
        echo "Proceeding with installation!"
    fi

    # Ensure all standard directories exist
    mkdir -p "${TEMP_DIR}"
    mkdir -p "${HOME}/.local/bin"
    mkdir -p "${HOME}/.config/systemd/user"

    # Download and install binary
    echo -ne "[1/7] Downloading microsocks...\r"
    curl -sL "https://github.com/rofl0r/microsocks/archive/refs/tags/v1.0.4.tar.gz" -o "${TEMP_DIR}/microsocks.tar.gz"
    echo -ne "[2/7] Extracting...\r"
    tar xf "${TEMP_DIR}/microsocks.tar.gz" --directory "${TEMP_DIR}" --strip-components=1
    echo -ne "[3/7] Compiling from source...\r"
    make --directory "${TEMP_DIR}" >/dev/null 2>&1
    echo -ne "[4/7] Moving into place... \r"
    mv "${TEMP_DIR}/microsocks" "${BIN_PATH}"
    echo -ne "[5/7] Cleaning up...\r"
    rm -rf "${TEMP_DIR}"

    # Set up the service
    echo -ne "[6/7] Creating service file...\r"
    cat > "${SERVICE_PATH}" << EOF
[Unit]
Description=A tiny SOCKS5 server
After=syslog.target network.target auditd.service

[Service]
Type=exec
ExecStart=$BIN_PATH -p $PORT -u $USER -P $PASS

[Install]
WantedBy=default.target
EOF
    echo -ne "[7/7] Starting microsocks...\r"
    systemctl --user enable --now microsocks.service >/dev/null 2>&1

    echo "### All done! ######################################################################################"
    echo "#                                                                                                  #"
    echo "#   microsocks has been installed successfully!                                                    #"
    echo "#                                                                                                  #"
    echo "#   You can connect with the credentials:                                                          #"
    echo "#       Host      $(hostname -f)                                                               #"
    echo "#       Port      ${PORT}                                                                            #"
    echo "#       User      (your seedbox username)                                                          #"
    echo "#       Password  ${PASS}                                                                 #"
    echo "#                                                                                                  #"
    echo "#   You can configure microsocks further by editing the service file at:                           #"
    echo "#       ~/.config/systemd/user/microsocks.service                                                  #"
    echo "#   and running:                                                                                   #"
    echo "#       systemctl --user restart microsocks.service                                                #"
    echo "#                                                                                                  #"
    echo "#   For more information, see https://github.com/rofl0r/microsocks.                                #"
    echo "#                                                                                                  #"
    echo "####################################################################################################"
}



function _uninstall() {
    echo -ne "[1/3] Stopping the service...\r"
    systemctl --user disable --now microsocks.service >/dev/null 2>&1
    echo -ne "[2/3] Removing the service file...\r"
    rm "${SERVICE_PATH}"
    echo -ne  "[3/3] Deleting the binary...\r"
    rm "${BIN_PATH}"
    
    echo "### All done! ######################################################################################"
    echo "#                                                                                                  #"
    echo "#   microsocks has been uninstalled successfully!                                                  #"
    echo "#                                                                                                  #"
    echo "####################################################################################################"
}



echo "### Welcome ########################################################################################"
echo "#                                                                                                  #"
echo "#   This script lets you install or uninstall microsocks in a hosted app server environment.       #"
echo "#                                                                                                  #"
echo "#   What would you like to do?                                                                     #"
echo "#     install         Install microsocks                                                           #"
echo "#     uninstall       Uninstall microsocks                                                         #"
echo "#     exit            Exit this script                                                             #"
echo "#                                                                                                  #"
echo "####################################################################################################"
while true; do
    read -r -p "=> "
    echo ""
    case $REPLY in
        "install")
            _install
            break
            ;;
        "uninstall")
            _uninstall
            break
            ;;
        *)
            echo "Exiting!"
            ;;
    esac
    exit
done
