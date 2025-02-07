#!/bin/bash
# thx flyingsausages and swizzin team
# based on the overseerr install script
export user=$(whoami)
mkdir -p $HOME/.logs/
touch $HOME/.logs/jellyseerr.log
export log="$HOME/.logs/jellyseerr.log"

function _deps() {
    ## Function for installing nvm.
    if [[ ! -d "$HOME/.nvm" ]]; then
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
    echo "Installing pnpm"
    npm install -g pnpm@9.15.5 >> "$log" 2>&1 || {
        echo "pnpm failed to install"
        exit 1
    }
    source "$HOME/.bashrc"
    echo "pnpm installed."
}

function _jellyseerr_install() {
    echo "Downloading and extracting source code"
    dlurl="$(curl -sS https://api.github.com/repos/Fallenbagel/jellyseerr/releases/latest | jq .tarball_url -r)"
    wget "$dlurl" -q -O /home/${user}/jellyseerr.tar.gz >> "$log" 2>&1 || {
        echo "Download failed"
        exit 1
    }
    mkdir -p $HOME/jellyseerr
    tar --strip-components=1 -C $HOME/jellyseerr -xzvf /home/${user}/jellyseerr.tar.gz >> "$log" 2>&1
    rm /home/${user}/jellyseerr.tar.gz
    echo "Code extracted"

    # Changing baseurl before build
    # export JELLYSEERR_BASEURL='/baseurl'
    
    # Bypass Node version requirement, build with latest LTS.
    sed -i 's|engine-strict=true|engine-strict=false|g' $HOME/jellyseerr/.npmrc
    
    echo "Installing dependencies via pnpm"
    pnpm install --prefix $HOME/jellyseerr >> "$log" 2>&1 || {
        echo "Failed to install dependencies"
        exit 1
    }
    echo "Dependencies installed"

    echo "Building jellyseerr"
    # Limit CPU
    sed -i "s|256000,|256000,\n    cpus: 6,|g" $HOME/jellyseerr/next.config.js
    pnpm --prefix $HOME/jellyseerr build >> "$log" 2>&1 || {
        echo "Failed to build jellyseerr sqlite"
        exit 1
    }
    echo "Succesfully built"
}

function _port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq "${LOW_BOUND}" "${UPPER_BOUND}" | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function _service() {
    mkdir -p "/home/$user/.config/systemd/user/"
    mkdir -p "/home/$user/.install/"
    mkdir -p "/home/$user/.config/jellyseerr/"
    # Adapted from https://aur.archlinux.org/cgit/aur.git/tree/overseerr.service?h=overseerr
    cat > $HOME/.config/systemd/user/jellyseerr.service << EOF
[Unit]
Description=Jellyseerr Service
Wants=network-online.target
After=network-online.target
[Service]
EnvironmentFile=%h/jellyseerr/env.conf
Environment=NODE_ENV=production
Type=exec
Restart=on-failure
WorkingDirectory=%h/jellyseerr
ExecStart=$(which node) dist/index.js
[Install]
WantedBy=default.target
EOF
    port=$(_port 1000 18000)
    cat > $HOME/jellyseerr/env.conf << EOF
# specify on which port to listen
PORT=$port
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now -q jellyseerr
    touch $HOME/.install/.jellyseerr.lock
    echo "Jellyseerr is up and running on http://$(hostname -f):$port/jellyseerr"

}

function _remove() {
    systemctl --user disable --now jellyseerr
    sleep 2
    rm -rf $HOME/jellyseerr
    rm -rf $HOME/.config/jellyseerr
    rm -rf $HOME/.config/systemd/user/jellyseerr.service
    rm -rf $HOME/.install/.jellyseerr.lock
}

echo 'This is unsupported software. You will not get help with this, please answer `yes` if you understand and wish to proceed'
if [[ -z ${eula} ]]; then
    read -r eula
fi

if ! [[ $eula =~ yes ]]; then
  echo "You did not accept the above. Exiting..."
  exit 1
else
  echo "Proceeding with installation"
fi

echo "Welcome to the Jellyseerr installer..."
echo ""
echo "What do you like to do?"
echo ""
echo "install = Install Jellyseerr"
echo "uninstall = Completely removes Jellyseerr"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            clear
            _deps
            _jellyseerr_install
            _service
            break
            ;;
        "uninstall")
            _remove
            break
            ;;
        "exit")
            break
            ;;
        *)
            echo "Unknown Option."
            ;;
    esac
done
exit
