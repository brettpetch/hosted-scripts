#!/bin/bash
user=$(whoami)
mkdir -p /home/${user}/.logs/
touch /home/${user}/.logs/nvm.log
log="/home/${user}/.logs/nvm.log"

function _nvm() {
    ## Function for installing nvm.
    if [[ ! -d /home/$user/.nvm ]]; then
        echo "Installing node"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash >> "$log" 2>&1
        echo "nvm installed."
    else
        echo "nvm is already installed."
    fi
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
    nvm install --lts >> "$log" 2>&1 || {
        echo "node failed to install"
        exit 1
    }
    echo "Node LTS installed."
}
