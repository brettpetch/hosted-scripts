#!/bin/bash
user="$(whomai)"
mkdir -p "$HOME/.logs/"
touch "$HOME/.logs/ngpost.log"
log="$HOME/.logs/ngpost.log"

function _install() {
    if [[ -f "/home/$user/.install/.ngpost.lock" ]]; then
        echo "ngpost is already installed."
        exit 0
    fi
    # Get dir structure ready
    echo "Starting ngPost installation"
    echo "Establishing directory structure"
    mkdir -p "$HOME/scripts"
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/.install"
    cd "$HOME/scripts"

    # Clone the repo
    echo "Cloning the ngPost repo"
    git clone "https://github.com/mbruel/ngPost.git" >> "$log" 2>&1 || {
        echo "Failed to clone repo. Exiting."
        exit 1
    }

    cd "$HOME/scripts/ngPost"|| {
        echo "$HOME/scripts/ngPost"
        exit 1
    }

    # checkout latest tag
    echo "Checking out the latest release"
    git fetch --tags >> "$log" 2>&1
    latestTag=$(git describe --tags $(git rev-list --tags --max-count=1))
    git checkout $latestTag >> "$log" 2>&1 || {
        echo "Failed to checkout latest tag. Exiting..."
        exit 1
    }

    cd "$HOME/scripts/ngPost/src" || {
        echo "failed to cd to $HOME/scripts/ngPost/src"
        exit 1
    }

    # build
    echo "Building with qt5"
    qmake -qt=qt5 >> "$log" 2>&1 || {
        echo "Failed to run qmake... Exiting"
        exit 1
    }

    make -j$(nproc) >> "$log" 2>&1 || {
        echo "Failed to build... Exiting"
        exit 1
    }

    # Add to PATH
    echo "adding to path"
    ln -s "$HOME/scripts/ngPost/src/ngPost" "$HOME/.local/bin/"
    . "$HOME/.profile"

    "$HOME/.local/bin/ngPost" --help || {
        echo "something went wrong... exiting"
        exit 1
    }

    touch "$HOME/.install/.ngpost.lock"
    echo "Successfully built and added to PATH. You may need to run . $HOME/.profile or restart your terminal window to have these changes take effect."
}

function _remove() {
    if [[ ! -f "/home/$user/.install/.ngpost.lock" ]]; then
        echo "ngpost is not installed."
        exit 0
    fi
    echo "Removing ngPost"
    rm -f "$HOME/.local/bin/ngPost"
    rm -rf "$HOME/scripts/ngPost"
    rm "$HOME/.install/.ngpost.lock"
    echo "ngPost has been removed successfully!"
}

echo "Welcome to The ngpost installer..."
echo ""
echo "What do you like to do?"
echo "install = Install ngPost"
echo "uninstall = Completely removes ngPost"
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