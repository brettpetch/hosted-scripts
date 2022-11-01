#!/bin/bash
user=$(whoami)
mkdir -p "$HOME/.logs/"
export log="$HOME/.logs/kavita.log"
touch "$log"

function port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq ${LOW_BOUND} ${UPPER_BOUND} | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function github_latest_version() {
    # Argument expects the author/repo format
    # e.g. swizzin/swizzin
    repo=$1
    curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/${repo}/releases/latest | grep -o '[^/]*$'
}

function _install() {
    echo "Beginning installation..."
    mkdir -p "$HOME/Kavita"
    mkdir -p "$HOME/.tmp"
    echo "Downloading Kavita"
    version=$(github_latest_version Kareadita/Kavita)
    dlurl="https://github.com/Kareadita/Kavita/releases/download/$version/kavita-linux-x64.tar.gz"
    wget "$dlurl" -O "$HOME/Kavita.tar.gz" >> "${log}" 2>&1 || {
        echo "Download failed"
        exit 1
    }
    tar xvf "$HOME/Kavita.tar.gz" -C $HOME >> "${log}" 2>&1
    chmod +x "$HOME/Kavita/Kavita"
    rm -f "$HOME/Kavita.tar.gz"
    mkdir -p "$HOME/.config/systemd/user"
    echo "Figuring out a port to host Kavita on..."
    port=$(port 4900 9900)
    echo "Writing Service File"
    cat > "$HOME/.config/systemd/user/kavita.service" <<- SERV
[Unit]
Description=Kavita server

[Service]
Type=simple
WorkingDirectory=$HOME/Kavita/
ExecStart=$HOME/Kavita/Kavita
TimeoutStopSec=20
KillMode=process
Restart=on-failure
StandardOutput=null
StandardError=syslog

[Install]
WantedBy=multi-user.target
SERV

    cat <<< $(jq ".Port = ${port}" "$HOME/Kavita/config/appsettings.json") > "$HOME/Kavita/config/appsettings.json"
    echo "Starting service..."
    systemctl enable --user --now kavita -q
    echo "Service stared."
    touch "$HOME/.install/.kavita.lock"
    echo "Kavita has been installed and should be running at http://$(hostname -f):${port}/registration/register"
}

function _upgrade() {
    if [ ! -f /install/.kavita.install ]; then
        echo "You ain't got no Kavita, whacha doen"
        exit 1
    fi
    echo "Downloading Kavita"
    version=$(github_latest_version Kareadita/Kavita)
    dlurl="https://github.com/Kareadita/Kavita/releases/download/$version/kavita-linux-x64.tar.gz"
    wget "$dlurl" -O "$HOME/Kavita.tar.gz" >> "${log}" 2>&1 || {
        echo "Download failed"
        exit 1
    }
    tar xvf "$HOME/Kavita.tar.gz" -C $HOME >> "${log}" 2>&1
    rm -f "$HOME/Kavita.tar.gz"
    systemctl try-restart --user kavita
}

function _remove() {
    systemctl stop --user kavita
    systemctl disable --user kavita
    rm -rf "$HOME/Kavita/"
    rm -f "$HOME/.config/systemd/user/kavita.service"
    rm -f "$HOME/.install/.kavita.lock"
}

echo "Welcome to the Kavita installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "install = Install Kavita"
echo "upgrade = upgrades Kavita to latest version"
echo "uninstall = Completely removes Kavita"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            _install
            break
            ;;
        "upgrade")
            _upgrade
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
