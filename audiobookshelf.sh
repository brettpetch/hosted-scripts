#!/bin/bash
# Installer modified by TL27

user=$(whoami)
BASE_DIR="${HOME}/.config/audiobookshelf"

if [[ ! -d $HOME/.logs ]]; then
    mkdir -p $HOME/.logs
fi

touch "$HOME/.logs/audiobookshelf.log"
log="$HOME/.logs/audiobookshelf.log"

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

function audiobookshelf_install() {
    declare -a paths
    paths[1]="$BASE_DIR/ffmpeg"
    paths[2]="${HOME}/.config/systemd/user"
    paths[3]="${HOME}/bin"
    paths[4]="$BASE_DIR/tmp"
	
     for i in {1..4}; do
        if [ ! -d "${paths[${i}]}" ]; then
            mkdir -p "${paths[${i}]}"
        fi
    done

    ssl_port=$(port 14000 16000)
    port=$(port 10000 14000)
    domain=$(hostname -f)
	
	echo "Downloading Audiobookshelf..."
	mkdir -p "${HOME}/tmp/audiobookshelf" && cd "${HOME}/tmp/audiobookshelf"
	version=$(github_latest_version advplyr/audiobookshelf)
 
	wget -qO audiobookshelf.deb "https://github.com/advplyr/audiobookshelf-ppa/blob/master/audiobookshelf_${version//v/}_amd64.deb?raw=true" || {
		echo "Download failed."
		exit 1
	}
	
	ar x audiobookshelf.deb data.tar.xz
    tar xf data.tar.xz
	cp usr/share/audiobookshelf/audiobookshelf "$BASE_DIR"
	cd "${HOME}" && rm -rf "${HOME}/tmp"
	echo
	echo "Getting latest version of audiobookshelf-ffmpeg..."
    mkdir -p "${HOME}/.audiobookshelf-ffmpeg-tmp" && cd "${HOME}/.audiobookshelf-ffmpeg-tmp"
    rm -rf "$BASE_DIR/ffmpeg/*"
    wget -qO ffmpeg.tar.xz "https://johnvansickle.com/ffmpeg/builds/ffmpeg-git-amd64-static.tar.xz" || {
        echo "Failed to get latest release of audiobookshelf-ffmpeg." && exit 1
    }
    
    tar xf ffmpeg.tar.xz -C "$BASE_DIR/ffmpeg" --strip-components 1
    echo
    echo "Getting latest version of audiobookshelf-ffmpeg-tone..."    
    $((curl -s https://github.com/sandreas/tone | grep -om1 .*linux-x64.tar.gz) | sed s'/wget/wget -qO tone.tar.gz/g')
    tar xf tone.tar.gz -C "$BASE_DIR/ffmpeg" --strip-components 1
    
    cd "${HOME}" && rm -rf "${HOME}/.audiobookshelf-ffmpeg-tmp"
    echo
	
	if [[ ! -d $HOME/.config/systemd/user/ ]]; then
        mkdir -p $HOME/.config/systemd/user/
    fi
	
	echo "create systemd userservice"
	
	cat > "$HOME/.config/systemd/user/audiobookshelf.service" << EOF
	
[Unit]
Description=Self-hosted audiobook server for managing and playing audiobooks

[Service]
Type=simple
Environment=SOURCE=local
Environment=PORT=${port}
Environment=TMPDIR=$BASE_DIR/tmp
Environment=CONFIG_PATH=$BASE_DIR/config
Environment=METADATA_PATH=$BASE_DIR/metadata
Environment=FFMPEG_PATH=$BASE_DIR/ffmpeg/ffmpeg
Environment=FFPROBE_PATH=$BASE_DIR/ffmpeg/ffprobe
Environment=TONE_PATH=$BASE_DIR/ffmpeg/tone
WorkingDirectory=$BASE_DIR
ExecStart=$BASE_DIR/audiobookshelf
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always

[Install]
WantedBy=default.target
EOF
	
	echo "Starting Audiobookshelf"
	systemctl enable --now --user audiobookshelf.service
	echo
	echo "================================"
	echo "Audiobookshelf will be accessible at $(tput setaf 2)http://${domain}:${port}$(tput sgr0)"
	echo "================================"
	echo
	echo "Your library paths have to be entered manually as the File Browser function does not work on non-docker installs."
    echo "Click where it says $(tput setaf 4)New folder path$(tput sgr0)."
    echo "Your path MUST start with $(tput setaf 2)$(pwd -P)/$(tput sgr0) followed with with path to your audio books. e.g. $(tput setaf 2)$(pwd -P)/media/AudioBooks$(tput sgr0)"
    echo "Then TAB out of the field and click on $(tput setaf 4)Create $(tput sgr0)"
	
}

	function _remove() {
	echo
    echo "Uninstalling audiobookshelf.."
    if systemctl --user is-enabled --quiet "audiobookshelf.service" || [ -f "${HOME}/.config/systemd/user/audiobookshelf.service" ]; then
        systemctl --user stop audiobookshelf.service
        systemctl --user disable audiobookshelf.service
    fi
	
	rm -f "${HOME}/.config/systemd/user/audiobookshelf.service"
    systemctl --user daemon-reload
    systemctl --user reset-failed
    rm -rf "${HOME}/.config/audiobookshelf"
    rm -rf "${HOME}/bin"/audiobookshelf*
    echo
    echo "Uninstallation Complete."
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
		
	echo "Welcome to Audiobookshelf installer..."
	echo "Logs are stored at ${log}"
	echo ""
	echo "What do you like to do?"
	echo ""
	echo "install = Install Audiobookshelf"
	echo "uninstall = Completely removes Audiobookshelf"
	echo "exit = Exits Installer"
	echo ""
	
	
	while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            audiobookshelf_install
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