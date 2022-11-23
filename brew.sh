#!/bin/bash
# Homebrew Installer for Hosted

user=$(whoami)
mkdir -p "$HOME/.logs/"
export log="$HOME/.logs/homebrew.log"
touch "$log"

function _install() {
    git clone https://github.com/Homebrew/brew $HOME/homebrew
    eval "$($HOME/homebrew/bin/brew shellenv)"
    brew update --force --quiet
    brew analytics off
    chmod -R go-w "$(brew --prefix)/share/zsh"
    echo "eval \"\$(\$HOME/homebrew/bin/brew shellenv)\"" >> $HOME/.profile
    echo "Brew installed. Please run 'source \$HOME/.profile' to add the application to your shell environment."
    echo "Please note that this application will not be supported by any means at any point in time."
    echo "This includes asking for support in Discord."
}

function _remove() {
    rm $HOME/homebrew
}

echo "Welcome to the Homebrew installer..."
echo ""
echo "This action can cause irreperable damage."
echo "The application is not supported in any way."
echo "Use at your own risk."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "install = Install Homebrew"
echo "uninstall = Completely removes Homebrew"
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
