#!/bin/bash
# Channels DVR installer for Swizzin Hosted

function fetch() {
    curl -A "curl-dvr-installer-v1" -f -s "$1" -o "$2"
}

function port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq ${LOW_BOUND} ${UPPER_BOUND} | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function _install() {
    os=$(uname -s | tr '[A-Z]' '[a-z]')
    arch=$(uname -m)
    host="https://cdn.channelsdvr.net/dvr"
    version=$(fetch $host/latest.txt -)

    if [[ -z "$version" ]]; then
        echo "Failed to fetch latest version... Exiting!"
        exit 1
    fi

    mkdir -p "$HOME/channels-dvr/"{"${version}","data"}

    echo "Installing Channels DVR version $version for $os-$arch..."
    fetch $host/$version/$os-$arch.sha256       "$HOME/channels-dvr/$version/$os-$arch.sha256"
    fetch $host/$version/ffmpeg-$os-$arch       "$HOME/channels-dvr/$version/ffmpeg"
    fetch $host/$version/ffprobe-$os-$arch      "$HOME/channels-dvr/$version/ffprobe"
    fetch $host/$version/comskip-$os-$arch      "$HOME/channels-dvr/$version/comskip"
    fetch $host/$version/channels-dvr-$os-$arch "$HOME/channels-dvr/$version/channels-dvr"
    fetch $host/$version/ffmpeg-dl-$os-$arch    "$HOME/channels-dvr/$version/ffmpeg-dl"

    chmod +x $HOME/channels-dvr/$version/*
    ln -nsf "$version" "$HOME/channels-dvr/latest"

    port=$(port 10000 20000)
    subnet=$(cat "$HOME/.install/subnet.lock")

    cat > "$HOME/.config/systemd/user/channels-dvr.service" << EOF
[Unit]
Description=Channels DVR

[Service]
Type=simple
WorkingDirectory=$HOME/channels-dvr/data
ExecStart=$HOME/channels-dvr/latest/channels-dvr -dir $HOME/channels-dvr/data -port $port
Restart=always
RestartSec=10
LimitNOFILE=8192
OOMScoreAdjust=-500

[Install]
WantedBy=default.target
EOF


    systemctl --user daemon-reload
    systemctl --user enable --now channels-dvr
    echo "We strongly suggest you use a reverse proxy with channels-dvr for security and ease of access. See wireguard (official), cloudflared, or tailscale docs in hosted-scripts for additonal information."
    echo "Your subnet ip is ${subnet}, you may want to apply this by adding the \`-host\` flag to $HOME/.config/systemd/user/channels-dvr.service"
    echo "channels-dvr installed and accessible on http://$(hostname -f):$port - You are responsible for securing this software."
    touch "$HOME/.install/.channels-dvr.lock"
}

function _remove() {
  systemctl --user disable --now channels-dvr
  rm -rf "$HOME/.config/systemd/user/channels-dvr.service"
  rm -rf "$HOME/channels-dvr"
  rm -rf $HOME/.install/.channels-dvr.lock
}

echo "Welcome to the channels-dvr installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "install = Install channels-dvr"
echo "uninstall = Completely removes channels-dvr"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            _install
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
