#!/bin/bash
# Unpackerr Installer by b
# Swizzin/Seedbox.io 2021

user=$(whoami)
mkdir -p "/home/${user}/.logs/"
export log="/home/${user}/.logs/unpackerr.log"
touch "$log"
app="unpackerr"

function _get_latest_release() {
        case "$(dpkg --print-architecture)" in
        "amd64") arch='amd64' ;;
        "arm64") arch="arm64" ;;
        "armhf") arch="armhf" ;;
        "i386") arch="i386" ;;
        *)
            echo "Arch not supported"
            exit 1
            ;;
    esac
    latest=$(curl -sL https://api.github.com/repos/davidnewhall/unpackerr/releases/latest | grep "${arch}.linux" | grep browser_download_url | cut -d \" -f4) || {
        echo "Failed to query GitHub for latest version"
        exit 1
    }

    if ! curl "$latest" -L -o "/tmp/unpackerr.gz" >> "$log" 2>&1; then
        echo "Download failed, exiting"
        exit 1
    fi
    gzip -d "/tmp/unpackerr.gz" || {
        echo "Failed to extract"
        exit 1
    }
    mkdir -p "/home/${user}/.local/bin/"
    mv /tmp/unpackerr "/home/${user}/.local/bin/"
    chmod +x "/home/${user}/.local/bin/unpackerr"
    rm -rf /tmp/unpackerr.gz
    echo "Archive Extracted."
}

function _install() {

    echo "Downloading latest release"
    _get_latest_release
    echo "Latest release installed."

    echo "Configuring Unpackerr"
    subnet=$(cat "/home/${user}/.install/subnet.lock")
    mkdir -p "/home/${user}/.config/unpackerr"
    cat > "/home/${user}/.config/unpackerr/unpackerr.conf" << EOF
debug = false
quiet = false
log_files = 1
log_file_mb = 10
interval = "2m"
start_delay = "1m"
retry_delay = "5m"
parallel = 1
file_mode = "0644"
dir_mode = "0755"
EOF
    # Add API data to config for installed arrs.
    if [[ -f /home/${user}/.install/.sonarr.lock ]]; then 
        sonarr_base=$(sed -n 's|\(.*\)<UrlBase>\(.*\)</UrlBase>|\2|p' "/home/${user}/.config/Sonarr/config.xml")
        sonarr_api=$(sed -n 's|\(.*\)<ApiKey>\(.*\)</ApiKey>|\2|p' "/home/${user}/.config/Sonarr/config.xml")
        sonarr_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' "/home/${user}/.config/Sonarr/config.xml")
        echo "[[sonarr]]" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  url = \"http://${subnet}:${sonarr_port}/${sonarr_base}\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  api_key = \"${sonarr_api}\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  paths = [\"/home/${user}/torrents/rtorrent/\",\"/home/${user}/torrents/qbittorrent/\",\"/home/${user}/torrents/deluge/\"]" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  protocols = \"torrent\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  timeout = \"10s\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  delete_delay = \"5m\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  delete_orig = false" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
    fi
    
    if [[ -f /home/${user}/.install/.radarr.lock ]]; then
        radarr_api=$(sed -n 's|\(.*\)<ApiKey>\(.*\)</ApiKey>|\2|p' "/home/${user}/.config/Radarr/config.xml")
        radarr_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' "/home/${user}/.config/Radarr/config.xml")
        radarr_base=$(sed -n 's|\(.*\)<UrlBase>\(.*\)</UrlBase>|\2|p' "/home/${user}/.config/Radarr/config.xml")
        echo " [[radarr]]" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  url = \"http://${subnet}:${radarr_port}/${radarr_base}\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  api_key = \"${radarr_api}\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  paths = [\"/home/${user}/torrents/rtorrent/\",\"/home/${user}/torrents/qbittorrent/\",\"/home/${user}/torrents/deluge/\"]" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  protocols = \"torrent\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  timeout = \"10s\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  delete_delay = \"5m\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  delete_orig = false" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
    fi

    if [[ -f /home/${user}/.install/.lidarr.lock ]]; then
        lidarr_api=$(sed -n 's|\(.*\)<ApiKey>\(.*\)</ApiKey>|\2|p' "/home/${user}/.config/Lidarr/config.xml")
        lidarr_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' "/home/${user}/.config/Lidarr/config.xml")
        lidarr_base=$(sed -n 's|\(.*\)<UrlBase>\(.*\)</UrlBase>|\2|p' "/home/${user}/.config/Lidarr/config.xml")
        echo " [[lidarr]]" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  url = \"http://${subnet}:${lidarr_port}/${lidarr_base}\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  api_key = \"${lidarr_api}\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  paths = [\"/home/${user}/torrents/rtorrent/\",\"/home/${user}/torrents/qbittorrent/\",\"/home/${user}/torrents/deluge/\"]" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  protocols = \"torrent\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  timeout = \"10s\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  delete_delay = \"5m\"" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
        echo "  delete_orig = false" >> "/home/${user}/.config/unpackerr/unpackerr.conf"
    fi

    mkdir -p "/home/${user}/.config/systemd/user/"
    cat > "/home/${user}/.config/systemd/user/unpackerr.service" << EOF
[Unit]
Description=unpackerr - Extracts downloads so Radarr, Sonarr, Lidarr or Readarr may import them.

[Service]
ExecStart=/home/${user}/.local/bin/unpackerr --config /home/${user}/.config/unpackerr/unpackerr.conf
Restart=always
RestartSec=10
SyslogIdentifier=unpackerr
Type=simple
WorkingDirectory=/tmp

[Install]
WantedBy=multi-user.target
EOF
    echo "Starting the unpackerr service"
    systemctl enable --user --now unpackerr >> "$log" 2>&1
    touch "/home/${user}/.install/.unpackerr.lock"
    echo "Unpackerr installed."
}

function _remove() {
    echo "Removing unpackerr."
    systemctl stop --user unpackerr
    systemctl disable --user unpackerr
    rm -rf "/home/${user}/.config/unpackerr"
    rm -rf "/home/${user}/.local/bin/unpackerr"
    rm "/home/${user}/.install/.unpackerr.lock"
    echo "Unpackerr removed."
}

function _upgrade() {
    echo "Upgrading unpackerr."
    systemctl stop --user unpackerr
    _get_latest_release
    systemctl start --user unpackerr
    echo "Unpackerr has been Upgraded."
}

echo "Welcome to the Unpackerr installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "install = Install ${app}"
echo "upgrade = upgrades ${app} to latest version"
echo "uninstall = Completely removes ${app}"
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