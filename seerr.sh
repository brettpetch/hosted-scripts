#!/bin/bash
# thx flyingsausages and swizzin team
# based on the overseerr install script
export user=$(whoami)
mkdir -p $HOME/.logs/
touch $HOME/.logs/seerr.log
export log="$HOME/.logs/seerr.log"

function _deps() {
    ## Function for installing nvm.
    if [[ ! -d "$HOME/.nvm" ]]; then
        echo "Installing node"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/refs/heads/master/install.sh | bash >> "$log" 2>&1
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
    npm install -g pnpm@9 >> "$log" 2>&1 || {
        echo "pnpm failed to install"
        exit 1
    }
    source "$HOME/.bashrc"
    echo "pnpm installed."
}

function _seerr_install() {
    echo "Downloading and extracting source code"
    dlurl="$(curl -sS https://api.github.com/repos/seerr-team/seerr/releases/latest | jq .tarball_url -r)"
    wget "$dlurl" -q -O /home/${user}/seerr.tar.gz >> "$log" 2>&1 || {
        echo "Download failed"
        exit 1
    }
    mkdir -p $HOME/seerr
    tar --strip-components=1 -C $HOME/seerr -xzvf /home/${user}/seerr.tar.gz >> "$log" 2>&1
    rm /home/${user}/seerr.tar.gz
    echo "Code extracted"

    # Changing baseurl before build
    # export seerr_BASEURL='/baseurl'
    
    # Bypass Node version requirement, build with latest LTS.
    sed -i 's|engine-strict=true|engine-strict=false|g' $HOME/seerr/.npmrc
    
    echo "Installing dependencies via pnpm (this might take a while)"
    pnpm install --prefix $HOME/seerr >> "$log" 2>&1 || {
        echo "Failed to install dependencies"
        exit 1
    }
    echo "Dependencies installed"

    echo "Building seerr (this might take a while)"
    # Limit CPU
    sed -i "s|256000,|256000,\n    cpus: 6,|g" $HOME/seerr/next.config.js
    pnpm --prefix $HOME/seerr build >> "$log" 2>&1 || {
        echo "Failed to build seerr sqlite"
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
    mkdir -p "/home/$user/.config/seerr/"
    # Adapted from https://aur.archlinux.org/cgit/aur.git/tree/overseerr.service?h=overseerr
    cat > $HOME/.config/systemd/user/seerr.service << EOF
[Unit]
Description=seerr Service
Wants=network-online.target
After=network-online.target
[Service]
EnvironmentFile=%h/seerr/env.conf
Environment=NODE_ENV=production
Type=exec
Restart=on-failure
WorkingDirectory=%h/seerr
ExecStart=$(which node) dist/index.js
[Install]
WantedBy=default.target
EOF
    port=$(_port 1000 18000)
    cat > $HOME/seerr/env.conf << EOF
# specify on which port to listen
PORT=$port
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now -q seerr
    touch $HOME/.install/.seerr.lock
    echo "seerr is up and running on http://$(hostname -f):$port/seerr"

}

function _remove() {
    systemctl --user disable --now seerr
    sleep 2
    rm -rf $HOME/seerr
    rm -rf $HOME/.config/seerr
    rm -rf $HOME/.config/systemd/user/seerr.service
    rm -rf $HOME/.install/.seerr.lock
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

echo "Welcome to the seerr installer..."
echo ""
echo "What do you like to do?"
echo ""
echo "install = Install seerr"
echo "uninstall = Completely removes seerr"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            clear
            _deps
            _seerr_install
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
