#!/bin/bash
# thx flyingsausages and swizzin team
export user=$(whoami)
mkdir -p $HOME/.logs/
touch $HOME/.logs/maintainerr.log
export log="$HOME/.logs/maintainerr.log"

function _deps() {
    ## Function for installing nvm.
    if [[ ! -d $HOME/.nvm ]]; then
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
    echo "Installing Yarn"
    npm install -g yarn >> "$log" 2>&1 || {
        echo "Yarn failed to install"
        exit 1
    }
    echo "Yarn installed."
}

function _maintainerr_install() {
    echo "Downloading and extracting source code"
    mkdir -p "$HOME/.tmp"
    dlurl="$(curl -sS https://api.github.com/repos/jorenn92/Maintainerr/releases/latest | jq .tarball_url -r)"

    wget "$dlurl" -q -O /home/${user}/.tmp/maintainerr.tar.gz >> "$log" 2>&1 || {
        echo "Download failed"
        exit 1
    }

    mkdir -p $HOME/Maintainerr
    tar --strip-components=1 -C $HOME/Maintainerr -xzvf $HOME/.tmp/maintainerr.tar.gz >> "$log" 2>&1
    rm $HOME/.tmp/maintainerr.tar.gz
    echo "Code extracted"

    cd $HOME/Maintainerr || {
        echo "unable to cd into Maintainerr. Exiting!"
        exit 1
    }

    echo "Installing dependencies via yarn"
    export TMPDIR=$HOME/.tmp/

    corepack install >> "$log" 2>&1
    corepack enable >> "$log" 2>&1

    yarn --immutable --network-timeout 99999999 >> "$log" 2>&1 || {
        echo "Failed to install dependencies"
        exit 1
    }
    yarn add sharp >> "$log" 2>&1
    echo "Dependencies installed"
    serverPort=$(_port 6000 8000)

    echo "Changing server port to $serverPort before build."
    sed -i "s|3001|$serverPort|g" ./ui/next.config.js
    sed -i "s|3001|$serverPort|g" ./server/src/main.ts
    sed -i "s|3001|$serverPort|g" ./server/src/modules/api/internal-api/internal-api.service.ts

    echo "Building Maintainerr Server"
    yarn build:server >> "$log" 2>&1 || {
        echo "Failed to build Maintainerr server"
        exit 1
    }

    echo "Building Maintainerr UI. Get a coffee."
    yarn build:ui >> "$log" 2>&1 || {
        echo "Failed to build Maintainerr ui"
        exit 1
    }
    
    # Optional Docs
    # yarn docs-generate 
    # rm -rf ./docs

    echo "Succesfully built"
    echo "Cleaning up"

    # Prep for data dir (it doesn't make this itself)
    mkdir -p "$HOME/Maintainerr/data"
}

function _port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq "${LOW_BOUND}" "${UPPER_BOUND}" | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function _service() {
    # Create neccesary service dirs
    mkdir -p "$HOME/.config/systemd/user/"
    mkdir -p "$HOME/.install/"
    mkdir -p "$HOME/.config/Maintainerr/"
    cat > $HOME/.config/systemd/user/maintainerr-server.service << EOF
[Unit]
Description=Maintainerr UI Service
Wants=network-online.target
After=network-online.target
[Service]
Environment=NODE_VERSION=$(node -v | cut -d "v" -f 2 | cut -d "." -f 1)
Environment=TMPDIR=$HOME/.tmp/
Type=exec
Restart=on-failure
WorkingDirectory=$HOME/Maintainerr/server
ExecStart=$HOME/.nvm/versions/node/v20.13.1/bin/node dist/main
[Install]
WantedBy=default.target
EOF


    port=$(_port 1000 18000)
    cat > $HOME/.config/systemd/user/maintainerr-ui.service << EOU
[Unit]
Description=Maintainerr UI Service
Wants=network-online.target
After=network-online.target
[Service]
Environment=NODE_VERSION=$(node -v | cut -d "v" -f 2 | cut -d "." -f 1)
Environment=NODE_ENV=production
Environment=TMPDIR=$HOME/.tmp
Type=exec
Restart=on-failure
WorkingDirectory=$HOME/Maintainerr/ui/
ExecStart=$HOME/.nvm/nvm-exec yarn next start -p $port
[Install]
WantedBy=default.target
EOU

    systemctl --user daemon-reload
    systemctl --user enable --now -q maintainerr-server
    systemctl --user enable --now -q maintainerr-ui

    touch $HOME/.install/.maintainerr.lock
    echo "Maintainerr is up and running on http://$(hostname -f):$port"

}

function _remove() {
    systemctl --user disable --now maintainerr-ui
    systemctl --user disable --now maintainerr-server
    sleep 2
    rm -rf $HOME/maintainerr
    rm -rf $HOME/.config/maintainerr
    rm -rf $HOME/.config/systemd/user/maintainerr-ui.service
    rm -rf $HOME/.config/systemd/user/maintainerr-server.service
    rm -rf $HOME/.install/.maintainerr.lock
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

echo "Welcome to the Maintainerr installer..."
echo ""
echo "What do you like to do?"
echo ""
echo "install = Install Maintainerr"
echo "uninstall = Completely removes Maintainerr"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            clear
            _deps
            _maintainerr_install
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
