#!/bin/bash
# cross-seed Installer for SBIO/Swizzin Hosted
# Author: fabricionaweb

mkdir -p "$HOME/.logs"
log="$HOME/.logs/cross-seed.log"

function github_latest_version() {
    # Function by Liara from the Swizzin Project
    # Argument expects the author/repo format
    # e.g. swizzin/swizzin
    repo=$1
    curl -fsSLI -o /dev/null -w %{url_effective} "https://github.com/${repo}/releases/latest" | grep -o '[^/]*$'
}

function _deps() {
    ## Function for installing nvm.
    NVM_DIR=${NVM_DIR:-"$HOME/.nvm"}
    if [[ ! -d "$NVM_DIR" ]]; then
        echo "Installing nvm"
        nvmVersion=$(github_latest_version "nvm-sh/nvm")
        curl -fsSLo- "https://github.com/nvm-sh/nvm/raw/${nvmVersion}/install.sh" | bash >>"$log" 2>&1
        echo "nvm ${nvmVersion} installed."
    fi
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

    echo "Installing nodejs"
    nvm install --lts >>"$log" 2>&1 || {
        echo "nodejs failed to install."
        exit 1
    }
    nvm install-latest-npm >>"$log"
    npm config set update-notifier=false fund=false

    NODE_VERSION=$(node -v)
    echo "nodejs ${NODE_VERSION} / npm $(npm -v) installed."
}

function _install() {
    ## Install cross-seed
    echo "Installing cross-seed"
    npm install -g cross-seed >>"$log" 2>&1 || {
        echo "cross-seed failed to install."
        exit 1
    }

    mkdir -p "$HOME/.cross-seed"
    if [[ ! -f "$HOME/.cross-seed/config.js" ]]; then
        cross-seed gen-config >>"$log" 2>&1 || {
            echo "cross-seed failed to generate config"
            exit 1
        }

        # bind host to localhost
        sed -i 's|host: undefined|host: "127.0.0.1"|' "$HOME/.cross-seed/config.js"

        echo "config generated: ~/.cross-seed/config.js"
    else
        echo "config exists: ~/.cross-seed/config.js"
    fi

    echo "cross-seed $(cross-seed -V) installed."
}

function _upgrade() {
    ## Upgrade cross-seed
    if [[ ! -f "$HOME/.install/.cross-seed.lock" ]]; then
        echo "cross-seed is not installed."
        exit 0
    fi

    if [[ "$(systemctl --user is-enabled cross-seed.service 2>&1)" == "enabled" ]]; then
        restartDaemon=true
        echo "Stopping cross-seed systemd service"
        systemctl --user stop cross-seed.service >>"$log" 2>&1
    fi

    _install

    if [[ "$restartDaemon" == "true" ]]; then
        echo "Starting cross-seed systemd service"
        systemctl --user start cross-seed.service >>"$log" 2>&1
    fi
}

function _service() {
    ## Create user service
    echo "Installing systemd service"
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/cross-seed.service" << EOF
[Unit]
Description=cross-seed daemon

[Service]
Environment=NODE_VERSION=$NODE_VERSION
ExecStart=$NVM_DIR/nvm-exec cross-seed daemon
Restart=on-failure

[Install]
WantedBy=default.target
EOF

    mkdir -p "$HOME/.install"
    touch "$HOME/.install/.cross-seed.lock"

    echo ""
    echo "Additional configuration is required. Check the official documentation https://cross-seed.org"
    echo "Close and re-open the terminal or run \`source ~/.bashrc\`"
}

function _remove() {
    ## Remove cross-seed and files
    echo "Removing cross-seed"
    systemctl --user disable --now cross-seed.service >/dev/null 2>&1
    rm -f "$HOME/.config/systemd/user/cross-seed.service"
    npm uninstall -g cross-seed >>"$log" 2>&1
    rm -rf "$HOME/.cross-seed"
    rm -f "$HOME/.install/.cross-seed.lock"

    echo "cross-seed has been removed successfully!"
}

echo "This is unsupported software. You will not get help with this, please answer \`yes\` if you understand and wish to proceed"
if [[ -z ${eula} ]]; then
    read -r eula
fi

if ! [[ $eula =~ yes ]]; then
  echo "You did not accept the above. Exiting..."
  exit 1
else
  echo "Proceeding with installation"
fi

echo "Welcome to cross-seed installer..."
echo "Logs are stored at ${log}"
echo ""
echo "What do you like to do?"
echo ""
echo "install = Install cross-seed"
echo "uninstall = Completely removes cross-seed"
echo "upgrade = Upgrades cross-seed to latest version"
echo "exit = Exits Installer"
echo ""
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            clear
            _deps
            _install
            _service
            break
            ;;
        "uninstall")
            _remove
            break
            ;;
        "upgrade")
            _upgrade
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
