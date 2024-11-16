#!/bin/bash
# Recyclarr Installer for SBIO/Swizzin Hosted

function github_latest_version() {
    # Function by Liara from the Swizzin Project
    # Argument expects the author/repo format
    # e.g. swizzin/swizzin
    repo=$1
    curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/${repo}/releases/latest | grep -o '[^/]*$'
}

function _download() {
    # make $HOME/.tmp and $HOME/.local/bin dirs
    mkdir -p "$HOME/.tmp"
    mkdir -p "$HOME/.local/bin"
    echo "Downloading the latest Recyclarr release"
    # Download latest version of Recylarr via github releases
    latest=$(github_latest_version recyclarr/recyclarr)
    dlurl="https://github.com/recyclarr/recyclarr/releases/download/${latest}/recyclarr-linux-x64.tar.xz"
    curl -sLo "$HOME/.tmp/recyclarr.tar.xz" "${dlurl}" || {
        echo "Unable to download recyclarr. Exiting..."
        exit 1
    }
    echo "Recyclarr downloaded."
    tar xvf "$HOME/.tmp/recyclarr.tar.xz" -C $HOME/.local/bin/
    rm -f "$HOME/.tmp/recyclarr.tar.xz"
}

function _install() {
    _download
    # Create example config
    "$HOME/.local/bin/recyclarr" config create
    echo "Recylarr installed. Additional configuration is required. Please see https://recyclarr.dev/wiki/yaml/config-reference/ for additional setup information."
    touch $HOME/.install/.recyclarr.lock
}

function _update() {
    _download
}

function _remove() {
    rm -rf "$HOME/.config/recyclarr"
    rm -f "$HOME/.local/bin/recyclarr"
    rm -f $HOME/.install/.recyclarr.lock
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

echo "Welcome to the Recyclarr installer..."
echo ""
echo "What do you like to do?"
echo ""
echo "install = Install Recyclarr"
echo "upgrade = Completely removes Recyclarr"
echo "uninstall = Completely removes Recyclarr"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            _install
            break
            ;;
        "upgrade")
            _update
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
