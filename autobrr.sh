#!/bin/bash
# Refactored Swizzin version from Ze0s
user=$(whoami)
mkdir -p "$HOME/.logs/"
export log="$HOME/.logs/autobrr.log"
touch "$log"

function port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq ${LOW_BOUND} ${UPPER_BOUND} | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function autobrr_download_latest() {
    echo "Downloading autobrr release archive"

    case "$(dpkg --print-architecture)" in
        "amd64") arch='x86_64' ;;
        "arm64") arch="arm64" ;;
        "armhf") arch="armv6" ;;
        *)
            echo "Arch not supported"
            exit 1
            ;;
    esac

    latest=$(curl -sL https://api.github.com/repos/autobrr/autobrr/releases/latest | grep "linux_$arch" | grep browser_download_url | cut -d \" -f4) || {
        echo "Failed to query GitHub for latest version"
        exit 1
    }
    
    mkdir -p "$HOME/.tmp/"
    
    if ! curl "$latest" -L -o "$HOME/.tmp/autobrr.tar.gz" >> "$log" 2>&1; then
        echo "Download failed, exiting"
        exit 1
    fi
    echo "Archive downloaded"

    echo "Extracting archive"
    mkdir -p "$HOME/.local/bin/"
    # the archive contains both autobrr and autobrrctl to easily setup the user
    tar xfv "$HOME/.tmp/autobrr.tar.gz" --directory "$HOME/.local/bin/" >> "$log" 2>&1 || {
        echo "Failed to extract"
        exit 1
    }
    rm -rf "$HOME/.tmp/autobrr.tar.gz"
    echo "Archive extracted"
}

_systemd() {
    type=simple

    if [[ $(systemctl --version | awk 'NR==1 {print $2}') -ge 240 ]]; then
        type=exec
    fi
    echo "Installing Systemd service"
    mkdir -p "$HOME/.config/systemd/user/"
    cat > "$HOME/.config/systemd/user/autobrr.service" << EOF
[Unit]
Description=autobrr service
After=syslog.target network.target
[Service]
Type=${type}
ExecStart=$HOME/.local/bin/autobrr --config=$HOME/.config/autobrr/
[Install]
WantedBy=default.target
EOF
    echo "Service installed"
}

function _add_user {
    port=$(port 10000 12000)
    # generate a sessionSecret
    sessionSecret="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c16)"

    mkdir -p "$HOME/.config/autobrr/"
    cat > "$HOME/.config/autobrr/config.toml" << CFG
# config.toml
# Hostname / IP
#
# Default: "localhost"
#
host = "0.0.0.0"
# Port
#
# Default: 8989
#
port = ${port}
# Base url
# Set custom baseUrl eg /autobrr/ to serve in subdirectory.
# Not needed for subdomain, or by accessing with the :port directly.
#
# Optional
#
# baseUrl = "/autobrr/"
# autobrr logs file
# If not defined, logs to stdout
#
# Optional
#
logPath = "$HOME/.config/autobrr/logs/autobrr.log"
# Log level
#
# Default: "DEBUG"
#
# Options: "ERROR", "DEBUG", "INFO", "WARN"
#
logLevel = "DEBUG"
# Session secret
#
sessionSecret = "${sessionSecret}"
CFG
    read -rep "Please set a password for your autobrr user ${user}> " password
    echo "${password}" | "$HOME/.local/bin/autobrrctl" --config "$HOME/.config/autobrr" create-user "$user" || {
            echo "Failed to execute autobrrctl command"
            exit 1
        }
    systemctl --user enable --now  autobrr 2>&1 | tee -a "${log}"
    touch "$HOME/.install/.autobrr.lock"
    echo "autobrr is now installed and running at http://$(hostname -f):${port}/" | tee -a "${log}"
}

function _remove(){
    if [[ ! -f $HOME/.install/.autobrr.lock ]]; then 
        echo "Autobrr not installed!"
        exit 1
    fi
    systemctl stop --user autobrr
    systemctl disable --user autobrr
    rm "$HOME/.config/systemd/user/autobrr.service"
    rm -rf "$HOME/.config/autobrr"
    rm $HOME/.local/bin/*brr*
    rm "$HOME/.install/.autobrr.lock"
}

function _upgrade {
    if [[ ! -f $HOME/.install/.autobrr.lock ]]; then 
        echo "Autobrr not installed!"
        exit 1
    fi
    autobrr_download_latest
    systemctl try-restart --user autobrr
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

echo "Welcome to the AutoBrr installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "install = Install autobrr"
echo "upgrade = upgrades autobrr to latest version"
echo "uninstall = Completely removes autobrr"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            autobrr_download_latest
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
