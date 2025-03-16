#!/bin/bash
# Cloudflared Installer for HBD/Swizzin.net Appbox Environments

mkdir -p "$HOME/.logs/"
export log="$HOME/.logs/cloudflared.log"
touch "$log"


function github_latest_version() {
    # Argument expects the author/repo format
    # e.g. swizzin/swizzin
    repo=$1
    curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/${repo}/releases/latest | grep -o '[^/]*$'
}

function _install() {
    echo "Welcome to the cloudflared installer for HBD/Swizzin.net Appbox Environments"
    echo "This application requires that you have a Cloudflare account with a (sub)domain that can be utilized for services running on your slot."
    echo "If you don't have a domain, you can get one from https://porkbun.com (cheap) or https://njal.la (privacy oriented)"
    echo "You will then need to sign up for a free Cloudflare account at https://dash.cloudflare.com/"
    echo "Once you have your domain setup on Cloudflare, you will need to create your zero trust organization."
    echo "After you have created your organization, you will need to create a tunnel."
    echo "You may obtain your Zero Trust Token from https://one.dash.cloudflare.com/"
    echo "Select the account this is applicable to, then select 'Networks' then 'Tunnels' and create a new tunnel"

    mkdir -p "$HOME/.local/bin"
    echo "Downloading cloudflared"
    latest_version=$(github_latest_version cloudflare/cloudflared)
    curl -s -L "https://github.com/cloudflare/cloudflared/releases/download/${latest_version}/cloudflared-linux-amd64" -o "$HOME/.local/bin/cloudflared"
    chmod +x "$HOME/.local/bin/cloudflared"

    read -rep "Please enter your Cloudflare Zero Trust Tunnel Token:" CF_API_TOKEN 
    mkdir -p "$HOME/.config/cloudflared/"
    touch "$HOME/.config/cloudflared/config.yml"

    cat >> "$HOME/.config/systemd/user/cloudflared.service" <<EOF
[Unit]
Description=Cloudflared
After=network-online.target

[Service]
ExecStart=$HOME/.local/bin/cloudflared tunnel run --token $CF_API_TOKEN
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

    systemctl --user enable --now cloudflared
    echo "Successfully installed cloudflared."
    echo "You may continue with your configuration at https://one.dash.cloudflare.com/ - you will likely want to set your public hostnames to applications that you want to expose outside of your slot."
    echo "Your subnet ip is $(cat $HOME/.install/subnet.lock)"
}

function _remove() {
    systemctl --user stop cloudflared
    systemctl --user disable cloudflared
    rm -rf "$HOME/.config/cloudflared/"
    rm -rf "$HOME/.config/systemd/user/cloudflared.service"
    rm -rf "$HOME/.local/bin/cloudflared"
    echo "Cloudflared has been removed. Ensure that you remove your tunnel token at https://one.dash.cloudflare.com/"
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

echo "Welcome to the Cloudflared installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "install = Install Cloudflared"
echo "uninstall = Completely removes Cloudflared"
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
