#!/bin/bash
# cross-seed Installer for SBIO/Swizzin Hosted
# Author: fabricionaweb

mkdir -p "$HOME/.logs"
log="$HOME/.logs/cross-seed.log"
subnet=$(cat "$HOME/.install/subnet.lock")

function port() {
    ## Generating a random unused port
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq ${LOW_BOUND} ${UPPER_BOUND} | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

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

    # try to use existing nodejs
    if nvm use 22 >>"$log" 2>&1; then
        echo "Using previous installed nodejs v22"
    elif nvm use 20 >>"$log" 2>&1; then
        echo "Using previous installed nodejs v20"
    else
        echo "Installing nodejs lts"
        nvm install --lts >>"$log" 2>&1 || {
            echo "nodejs failed to install."
            exit 1
        }
    fi

    echo "Upgrading npm"
    nvm install-latest-npm >>"$log"
    npm config set update-notifier=false fund=false

    NODE_VERSION=$(node -v)
    echo "nodejs $NODE_VERSION / npm $(npm -v)"
}

function _install() {
    ## Install cross-seed
    echo "Installing cross-seed"
    npm install -g cross-seed >>"$log" 2>&1 || {
        echo "cross-seed failed to install."
        exit 1
    }
    echo "cross-seed $(cross-seed -V) installed."

    mkdir -p "$HOME/.cross-seed"
    if [[ ! -f "$HOME/.cross-seed/config.js" ]]; then
        echo "Making config file"
        cross-seed gen-config >>"$log" 2>&1 || {
            echo "cross-seed failed to generate config"
            exit 1
        }

        _config
    else
        echo "config exists: ~/.cross-seed/config.js"
    fi
}

function _config() {
    configFile="$HOME/.cross-seed/config.js"
    daemonPort=$(port 12000 14000)

    clientArray=()
    [ -f "$HOME/.install/.deluge.lock" ] && clientArray+=("Deluge")
    [ -f "$HOME/.install/.qbittorrent.lock" ] && clientArray+=("qBittorrent")
    [ -f "$HOME/.install/.rtorrent.lock" ] && clientArray+=("rTorrent")

    if [[ ${#clientArray[*]} -ge 2 ]]; then
        echo "Multiple clients detected. Please choose one to setup paths"
        for i in "${!clientArray[@]}"; do
            echo "$i = ${clientArray[$i]}"
        done

        while true; do
            read -r -p "Enter it here: " selectedIndex
            [[ ! $selectedIndex =~ ^[0-9]+$ || -z "${clientArray[$selectedIndex]}" ]] && echo "Invalid option" || break
        done
    fi

    case "${clientArray[$selectedIndex]}" in
        "Deluge")
            torrentDir="$HOME/.config/deluge/state"
            savePath=$(grep '"download_location"' "$HOME/.config/deluge/core.conf" | awk -F '"' '{print $4}')
            ;;
        "qBittorrent")
            torrentDir="$HOME/.local/share/qBittorrent/BT_backup"
            savePath=$(grep 'Downloads\\SavePath=' "$HOME/.config/qBittorrent/qBittorrent.conf" | awk -F '=' '{print $2}')
            # set the qbittorrentUrl because it can bypass authentication for the subnet
            webuiPort=$(grep 'WebUI\\Port=' "$HOME/.config/qBittorrent/qBittorrent.conf" | awk -F '=' '{print $2}')
            sed -i "s|qbittorrentUrl:.*,|qbittorrentUrl: \"http://$subnet:$webuiPort\",|" "$configFile"
            ;;
        "rTorrent")
            torrentDir="$HOME/.sessions"
            savePath=$(grep "directory.default.set" "$HOME/.rtorrent.rc" | awk '{print $3}')
            ;;
    esac

    if [[ -n "${clientArray[$selectedIndex]}" ]]; then
        mkdir -p "$savePath/cross-seed"
        sed -i "s|linkDir:.*,|linkDir: \"${savePath%/}/cross-seed\",|" "$configFile"
        sed -i "s|torrentDir:.*,|torrentDir: \"$torrentDir\",|" "$configFile"
    fi

    mkdir -p "$HOME/.cross-seed/output"
    sed -i "s|outputDir:.*,|outputDir: \"$HOME/.cross-seed/output\",|" "$configFile"
    sed -i 's|host:.*,|host: "127.0.0.1",|' "$configFile"
    sed -i "s|port:.*,|port: $daemonPort,|" "$configFile"

    echo "config generated: ~/.cross-seed/config.js"
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
