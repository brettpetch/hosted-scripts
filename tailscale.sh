#!/bin/bash
# Tailscale with userland wireguard

mkdir -p "$HOME/.logs/"
export log="$HOME/.logs/tailscale.log"
touch "$log"

function github_latest_version() {
    # Argument expects the author/repo format
    # e.g. swizzin/swizzin
    repo=$1
    curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/${repo}/releases/latest | grep -o '[^/]*$'
}


function _install(){
    version=$(github_latest_version "tailscale/tailscale")
    mkdir -p "$HOME/.local/bin"
    echo "Downloading tailscale"
    # Tempdir
    mkdir -p "$HOME/.tmp"
    # Download
    curl -sL "https://pkgs.tailscale.com/stable/tailscale_${version//v}_amd64.tgz" -o "$HOME/.tmp/tailscale.tgz"
    tar -xzf "$HOME/.tmp/tailscale.tgz" -C "$HOME/.tmp/"
    mv "$HOME/.tmp/tailscale_${version//v}_amd64/tailscale" "$HOME/.local/bin/tailscale"
    mv "$HOME/.tmp/tailscale_${version//v}_amd64/tailscaled" "$HOME/.local/bin/tailscaled"
    chmod +x "$HOME/.local/bin/tailscale"
    chmod +x "$HOME/.local/bin/tailscaled"
    rm -rf "$HOME/.tmp/tailscale_${version//v}_amd64/"
    rm -f "$HOME/.tmp/tailscale.tgz"

    # Configure Tailscale"
    mkdir -p "$HOME/.config/tailscale"
    echo "Setting up tailscale userland environment"
    cat > $HOME/.config/tailscale/env.conf << EOE
TAILSCALED_SOCKET="$HOME/.tmp/tailscaled.sock"
TAILSCALED_STATE="$HOME/.tmp/tailscale/tailscaled.state"
EOE

    mkdir -p "$HOME/.config/systemd/user"
    echo "Installing tailscaled service"
    cat > "$HOME/.config/systemd/user/tailscaled.service" << EOS
[Unit]
Description=Tailscale Daemon
After=network.target

[Service]
EnvironmentFile=$HOME/.config/tailscale/env.conf
ExecStart=$HOME/.local/bin/tailscaled --tun=userspace-networking --state=$HOME/.tmp/tailscale/tailscaled.state --socket=$HOME/.tmp/tailscale/tailscaled.sock
Restart=always
RestartSec=3
StartLimitInterval=0
StartLimitBurst=10

[Install]
WantedBy=default.target

EOS

    systemctl --user enable --now tailscaled
    echo "Tailscaled started"
    echo "Setting up tailscale"
    tailscale --socket="$HOME/.tmp/tailscale/tailscaled.sock" up

    echo "Writing tailscale alias to bashrc"
    echo "alias tailscale='$HOME/.local/bin/tailscale --socket=$HOME/.tmp/tailscale/tailscaled.sock'" >> "$HOME/.bashrc"

    echo "Tailscale installed. Please run 'source $HOME/.bashrc' via ssh or open a new ssh connection to start using tailscale"
}

function _upgrade(){
    systemctl --user stop tailscaled
    version=$(github_latest_version "tailscale/tailscale")
    curl -sL "https://pkgs.tailscale.com/stable/tailscale_${version//v}_amd64.tgz" -o "$HOME/.tmp/tailscale.tgz"
    tar -xzf "$HOME/.tmp/tailscale.tgz" -C "$HOME/.tmp/"
    mv "$HOME/.tmp/tailscale_${version//v}_amd64/tailscale" "$HOME/.local/bin/tailscale"
    mv "$HOME/.tmp/tailscale_${version//v}_amd64/tailscaled" "$HOME/.local/bin/tailscaled"
    
    chmod +x "$HOME/.local/bin/tailscale"
    chmod +x "$HOME/.local/bin/tailscaled"
    rm -rf "$HOME/.tmp/tailscale_${version//v}_amd64/"
    systemctl --user restart tailscaled
}

function _remove(){
    "$HOME/.local/bin/tailscale" --socket="$HOME/.tmp/tailscale/tailscaled.sock" logout
    systemctl --user stop tailscaled
    systemctl --user disable --now tailscaled
    rm -f "$HOME/.local/bin/tailscale"
    rm -f "$HOME/.local/bin/tailscaled"
    rm -rf "$HOME/.tmp/tailscale"
    rm -rf "$HOME/.config/tailscale/"
    rm -rf "$HOME/.local/share/tailscale"
    rm -f "$HOME/.config/systemd/user/tailscaled.service"
    sed -i "s|alias tailscale=.*||g" "$HOME/.bashrc"
    echo "Tailscale removed"
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

echo "Welcome to the Tailscale installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "install = Install Tailscale"
echo "upgrade = Upgrade Tailscale"
echo "uninstall = Completely removes Tailscale"
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
