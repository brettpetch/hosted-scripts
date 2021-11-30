#!/bin/bash
# bpetch 2021
user=$(whoami)
mkdir -p ~/.logs/
touch ~/.logs/requestrr.log
log="$HOME/.logs/requestrr.log"

function _port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq "${LOW_BOUND}" "${UPPER_BOUND}" | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function _os_arch() {
    dpkg --print-architecture
}

function _requestrr_download() {
    echo "Downloading source files"
    case "$(_os_arch)" in
        "amd64") dlurl=$(curl -sNL https://api.github.com/repos/darkalfx/requestrr/releases/latest | grep -Po 'ht(.*)linux-x64(.*)zip') >> "${log}" 2>&1 ;;
        "armhf") dlurl=$(curl -sNL https://api.github.com/repos/darkalfx/requestrr/releases/latest | grep -Po 'ht(.*)linux-arm(.*)zip') >> "${log}" 2>&1 ;;
        "arm64") dlurl=$(curl -sNL https://api.github.com/repos/darkalfx/requestrr/releases/latest | grep -Po 'ht(.*)linux-arm64(.*)zip') >> "${log}" 2>&1 ;;
        *)
            echo "Arch not supported"
            exit 1
            ;;
    esac

    if ! curl "$dlurl" -L -o /tmp/requestrr.zip >> "$log" 2>&1; then
        echo "Download failed, exiting"
        exit 1
    fi
    echo "Source downloaded"
}
# shellcheck disable=SC2086

function _get_sonarr_vars() {
    if [[ -f ~/.install/.sonarr.lock ]]; then
        echo "Found Sonarr. Grabbing config."
        # Grab config deets from xml
        export s_address=$(sed -n 's|\(.*\)<BindAddress>\(.*\)</BindAddress>|\2|p' /home/${user}/.config/Sonarr/config.xml)
        export s_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' /home/${user}/.config/Radarr/config.xml)
        export s_base=$(sed -n 's|\(.*\)<UrlBase>\(.*\)</UrlBase>|\2|p' /home/${user}/.config/Radarr/config.xml)
        export s_key=$(sed -n 's|\(.*\)<ApiKey>\(.*\)</ApiKey>|\2|p' /home/${user}/.config/Radarr/config.xml)
        echo "Grabbed Sonarr config."
    else
        export s_port="8989"
    fi
}

function _get_radarr_vars() {
    if [[ -f ~/.install/.radarr.lock ]]; then
        echo "Found Radarr. Grabbing config."
        # Grab config deets from xml
        export r_address=$(sed -n 's|\(.*\)<BindAddress>\(.*\)</BindAddress>|\2|p' "/home/${user}/.config/Radarr/config.xml")
        export r_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' "/home/${user}/.config/Radarr/config.xml")
        export r_base=$(sed -n 's|\(.*\)<UrlBase>\(.*\)</UrlBase>|\2|p' "/home/${user}/.config/Radarr/config.xml")
        export r_key=$(sed -n 's|\(.*\)<ApiKey>\(.*\)</ApiKey>|\2|p' "/home/${user}/.config/Radarr/config.xml")
        echo "Radarr config has been retrieved."
    else
        export r_port="7878"
    fi
}

function _write_configs() {
    _get_radarr_vars
    _get_sonarr_vars
    cat > ~/Requestrr/SettingsTemplate.json << CFG
{
  "Authentication": {
    "Username": "",
    "Password": "",
    "PrivateKey": "[PRIVATEKEY]"
  },
  "ChatClients": {
    "Discord": {
      "BotToken": "",
      "ClientId": "",
      "StatusMessage": "!help",
      "TvShowRoles": [],
      "MovieRoles": [],
      "MonitoredChannels": [],
      "EnableRequestsThroughDirectMessages": false,
      "AutomaticallyNotifyRequesters": true,
      "NotificationMode": "PrivateMessages",
      "NotificationChannels": [],
      "AutomaticallyPurgeCommandMessages": false,
      "DisplayHelpCommandInDMs": true
    }
  },
  "DownloadClients": {
    "Ombi": {
      "Hostname": "",
      "Port": 3579,
      "ApiKey": "",
      "ApiUsername": "",
      "BaseUrl": "",
      "UseSSL": false,
      "Version": "3"
    },
    "Overseerr": {
      "Hostname": "",
      "Port": 5055,
      "ApiKey": "",
      "DefaultApiUserID": "",
      "UseSSL": false,
      "Version": "1"
    },
    "Radarr": {
      "Hostname": "${r_address}",
      "Port": ${r_port},
      "ApiKey": "${r_key}",
      "BaseUrl": "/${r_base}",
      "MovieProfileId": "1",
      "MovieRootFolder": "",
      "MovieMinimumAvailability": "",
      "MovieTags": [],
      "AnimeProfileId": "1",
      "AnimeRootFolder": "",
      "AnimeMinimumAvailability": "",
      "AnimeTags": [],
      "SearchNewRequests": true,
      "MonitorNewRequests": true,
      "UseSSL": false,
      "Version": "2"
    },
    "Sonarr": {
      "Hostname": "${s_address}",
      "Port": ${s_port},
      "ApiKey": "${s_key}",
      "BaseUrl": "/${s_base}",
      "TvProfileId": "1",
      "TvRootFolder": "",
      "TvTags": [],
      "TvLanguageId": "1",
      "TvUseSeasonFolders": true,
      "AnimeProfileId": "1",
      "AnimeRootFolder": "",
      "AnimeTags": [],
      "AnimeLanguageId": "1",
      "AnimeUseSeasonFolders": true,
      "SearchNewRequests": true,
      "MonitorNewRequests": true,
      "UseSSL": false,
      "Version": "3"
    }
  },
  "BotClient": {
    "Client": "",
    "CommandPrefix": "!"
  },
  "Movies": {
    "Client": "Disabled",
    "Command": "movie"
  },
  "TvShows": {
    "Client": "Disabled",
    "Command": "tv",
    "Restrictions": "None"
  },
  "Port": $port,
  "BaseUrl" : "/requestrr",
  "Version": "1.12.0"
}
CFG

    echo "Requestrr config applied."

    echo "Installing Systemd service"
    cat > ~/.config/systemd/user/requestrr.service << EOF
[Unit]
Description=Requestrr Daemon
After=syslog.target network.target
[Service]
Type=simple
WorkingDirectory=/home/$user/Requestrr/
ExecStart=/home/$user/Requestrr/Requestrr.WebApi
TimeoutStopSec=20
KillMode=process
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

    cat > ~/Requestrr/appsettings.json << SET
{
  "Logging": {
    "LogLevel": {
      "Default": "None"
    }
  },
  "AllowedHosts": "*"
}
SET
}
function _install() {
    if [[ ! -f ~/.install/.requestrr.lock ]]; then
        port=$(_port 1000 18000)
        _requestrr_download
        unzip -q /tmp/requestrr.zip -d ~/ >> "${log}" 2>&1
        rm -rf /tmp/requestrr.zip
        mkdir -p ~/Requestrr
        mv ~/requestrr*/* ~/Requestrr
        rm -rf ~/requestrr*/
        echo "archive extracted."
        chmod u+x ~/Requestrr/Requestrr.WebApi
        echo "Requestrr permissions set"
        mkdir -p ~/.config/Requestrr/
        mkdir -p ~/.config/systemd/user/
        echo "Configuring "
        _write_configs
        systemctl --user -q enable --now requestrr >> "${log}" 2>&1
        touch ~/.install/.requestrr.lock
        echo "Requestrr service installed and enabled"
        echo "Requestrr is available at http://$(hostname -f):$port/requestrr ;Secure your installation manually through the web interface."
    else
        echo "requestrr is already installed."
    fi
}

function _remove() {
    systemctl --user disable --now requestrr
    sleep 2
    rm -rf ~/Requestrr
    rm -rf ~/.config/Requestrr
    rm -rf ~/.config/systemd/user/requestrr.service
    rm -rf ~/.install/.requestrr.lock
}

echo "What do you like to do?"
echo ""
echo "install = Install Requestrr"
echo "uninstall = Completely removes Requestrr"
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
