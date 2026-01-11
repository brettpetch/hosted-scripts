#!/bin/bash
# Refactored Swizzin version from ze0s / s0up
user=$(whoami)
mkdir -p "$HOME/.logs/"
export log="$HOME/.logs/qui.log"
touch "$log"

function port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq ${LOW_BOUND} ${UPPER_BOUND} | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function qui_download_latest() {
    echo "Downloading qui release archive"

    case "$(dpkg --print-architecture)" in
        "amd64") arch='x86_64' ;;
        "arm64") arch="arm64" ;;
        "armhf") arch="armv6" ;;
        *)
            echo "Arch not supported"
            exit 1
            ;;
    esac

    latest=$(curl -sL https://api.github.com/repos/autobrr/qui/releases/latest | grep "linux_$arch" | grep browser_download_url | cut -d \" -f4) || {
        echo "Failed to query GitHub for latest version"
        exit 1
    }
    
    mkdir -p "$HOME/.tmp/"
    
    if ! curl "$latest" -L -o "$HOME/.tmp/qui.tar.gz" >> "$log" 2>&1; then
        echo "Download failed, exiting"
        exit 1
    fi
    echo "Archive downloaded"

    echo "Extracting archive"
    mkdir -p "$HOME/.local/bin/"
    # the archive contains both qui to easily setup the user
    tar xfv "$HOME/.tmp/qui.tar.gz" --directory "$HOME/.local/bin/" >> "$log" 2>&1 || {
        echo "Failed to extract"
        exit 1
    }
    rm -rf "$HOME/.tmp/qui.tar.gz"
    echo "Archive extracted"
}

_systemd() {
    type=simple

    if [[ $(systemctl --version | awk 'NR==1 {print $2}') -ge 240 ]]; then
        type=exec
    fi
    echo "Installing Systemd service"
    mkdir -p "$HOME/.config/systemd/user/"
    cat > "$HOME/.config/systemd/user/qui.service" << EOF
[Unit]
Description=qui service
After=syslog.target network.target
[Service]
Type=${type}
ExecStart=$HOME/.local/bin/qui serve --config-dir=$HOME/.config/qui/
[Install]
WantedBy=default.target
EOF
    echo "Service installed"
}

function _add_user {
    port=$(port 10300 10500)
    # generate a sessionSecret
    sessionSecret="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c16)"

    mkdir -p "$HOME/.config/qui/"
    cat > "$HOME/.config/qui/config.toml" << CFG
# qui Configuration
host = "0.0.0.0"
port = ${port}
baseUrl = "/" # /qui/ if using nginx.
level = "INFO"  # ERROR, DEBUG, INFO, WARN, TRACE
sessionSecret = "${sessionSecret}"
CFG
    read -rep "Please set a password for your qui user ${user}> " password
    echo "${password}" | "$HOME/.local/bin/qui" create-user --config-dir "$HOME/.config/qui" --username "$user" --password "$password" || {
            echo "Failed to execute quictl command"
            exit 1
        }
    systemctl --user enable --now qui 2>&1 | tee -a "${log}"
    touch "$HOME/.install/.qui.lock"
    echo "qui is now installed and running at http://$(hostname -f):${port}/" | tee -a "${log}"
}

function _remove(){
    if [[ ! -f $HOME/.install/.qui.lock ]]; then 
        echo "qui not installed!"
        exit 1
    fi
    systemctl stop --user qui
    systemctl disable --user qui
    rm "$HOME/.config/systemd/user/qui.service"
    rm -rf "$HOME/.config/qui"
    rm $HOME/.local/bin/*brr*
    rm "$HOME/.install/.qui.lock"
}

function _upgrade {
    if [[ ! -f $HOME/.install/.qui.lock ]]; then 
        echo "qui not installed!"
        exit 1
    fi
    qui_download_latest
    systemctl try-restart --user qui
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

echo "Welcome to the qui installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "install = Install qui"
echo "upgrade = upgrades qui to latest version"
echo "uninstall = Completely removes qui"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            qui_download_latest
            _systemd
            _add_user
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
