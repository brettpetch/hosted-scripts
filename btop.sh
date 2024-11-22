#!/bin/bash

function github_latest_version() {
    repo=$1
    curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/${repo}/releases/latest | grep -o '[^/]*$'
}

function btop_install() {
    echo "Downloading btop++..."
	mkdir -p "${HOME}/tmp" && cd "${HOME}/tmp"
	version=$(github_latest_version aristocratos/btop)
    echo ${version}
 
	wget -qO btop.tbz "https://github.com/aristocratos/btop/releases/download/${version}/btop-x86_64-linux-musl.tbz" || {
		echo "Download failed."
		exit 1
	}

    echo "Extracting btop++..."
    tar xf btop.tbz
    rm btop.tbz

    mv ${HOME}/tmp/btop/bin/btop ${HOME}/.local/bin
    rm -rf {HOME}/tmp/btop

    echo "You can now start btop"
}

function _remove() {
    rm ${HOME}/.local/bin/btop
    rm -rf ${HOME}/.config/btop
    echo "btop removed"
}

echo "Welcome to btop++ installer..."
	echo ""
	echo "What do you like to do?"
	echo ""
	echo "install = Install btop++"
	echo "uninstall = Completely removes btop++"
	echo "exit = Exits Installer"
	echo ""
	
	
	while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            btop_install
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