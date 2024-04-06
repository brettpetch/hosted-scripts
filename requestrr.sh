#!/bin/bash
user=$(whoami)
mkdir -p "$HOME/.logs/"
touch "$HOME/.logs/requestrr.log"
log="$HOME/.logs/requestrr.log"

function _port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq ${LOW_BOUND} ${UPPER_BOUND} | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function _os_arch() {
    dpkg --print-architecture
}

function github_latest_version() {
    # Argument expects the author/repo format
    # e.g. swizzin/swizzin
    repo=$1
    curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/${repo}/releases/latest | grep -o '[^/]*$'
}

function _requestrr_download() {
    echo "Downloading source files"
    version=$(github_latest_version thomst08/requestrr)
    case "$(_os_arch)" in
        "amd64") arch=x64 ;;
        "armhf") arch=arm ;;
        "arm64") arch=arm64 ;;
        *)
            echo "Arch not supported"
            exit 1
            ;;
    esac
    
    dlurl="https://github.com/thomst08/requestrr/releases/download/${version}/requestrr-linux-${arch}.zip"
    mkdir -p "$HOME/.tmp"
    
    if ! curl "$dlurl" -L -o $HOME/.tmp/requestrr.zip >> "$log" 2>&1; then
        echo "Download failed, exiting"
        exit 1
    fi
    
    echo "Requestrr downloaded"
}
# shellcheck disable=SC2086

function _get_sonarr_vars() {
    if [[ -f $HOME/.install/.sonarr.lock ]]; then
        echo "Found Sonarr. Grabbing config."
        # Grab config deets from xml
        export s_address=$(sed -n 's|\(.*\)<BindAddress>\(.*\)</BindAddress>|\2|p' $HOME/.config/Sonarr/config.xml) >> ${log} 2>&1
        export s_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' $HOME/.config/Radarr/config.xml) >> ${log} 2>&1
        export s_base=$(sed -n 's|\(.*\)<UrlBase>\(.*\)</UrlBase>|\2|p' $HOME/.config/Radarr/config.xml) >> ${log} 2>&1
        export s_key=$(sed -n 's|\(.*\)<ApiKey>\(.*\)</ApiKey>|\2|p' $HOME/.config/Radarr/config.xml) >> ${log} 2>&1
        echo "Grabbed Sonarr config."
    else
        export s_port="8989"
    fi
}

function _get_radarr_vars() {
    if [[ -f $HOME/.install/.radarr.lock ]]; then
        echo "Found Radarr. Grabbing config."
        # Grab config deets from xml
        export r_address=$(sed -n 's|\(.*\)<BindAddress>\(.*\)</BindAddress>|\2|p' $HOME/.config/Radarr/config.xml) >> ${log} 2>&1
        export r_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' $HOME/.config/Radarr/config.xml) >> ${log} 2>&1
        export r_base=$(sed -n 's|\(.*\)<UrlBase>\(.*\)</UrlBase>|\2|p' $HOME/.config/Radarr/config.xml) >> ${log} 2>&1
        export r_key=$(sed -n 's|\(.*\)<ApiKey>\(.*\)</ApiKey>|\2|p' $HOME/.config/Radarr/config.xml) >> ${log} 2>&1
        echo "Radarr config has been retrieved."
    else
        export r_port="7878"
    fi
}

function _write_configs() {
    _get_radarr_vars
    _get_sonarr_vars
    mkdir -p "$HOME/Requestrr/config/"
    cat > "$HOME/Requestrr/SettingsTemplate.json" << CFG
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
      "StatusMessage": "/help",
      "TvShowRoles": [],
      "MovieRoles": [],
      "MonitoredChannels": [],
      "EnableRequestsThroughDirectMessages": false,
      "AutomaticallyNotifyRequesters": true,
      "NotificationMode": "PrivateMessages",
      "NotificationChannels": [],
      "AutomaticallyPurgeCommandMessages": true
    },
    "Language": "english"
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
      "Movies": {
        "DefaultApiUserID": "",
        "Categories": []
      },
      "TvShows": {
        "DefaultApiUserID": "",
        "Categories": []
      },
      "UseSSL": false,
      "Version": "1",
      "UseMovieIssue": false,
      "UseTVIssue": false
    },
    "Radarr": {
      "Hostname": "${r_address}",
      "Port": ${r_port},
      "ApiKey": "${r_key}",
      "BaseUrl": "/${r_base}",
      "Categories": [
        {
          "Id": 0,
          "Name": "movie",
          "ProfileId": "1",
          "RootFolder": "",
          "MinimumAvailability": "announced",
          "Tags": []
        }
      ],
      "SearchNewRequests": true,
      "MonitorNewRequests": true,
      "UseSSL": false,
      "Version": "3"
    },
    "Sonarr": {
      "Hostname": "${s_address}",
      "Port": ${s_port},
      "ApiKey": "${s_key}",
      "BaseUrl": "/${s_base}",
      "Categories": [
        {
          "Id": 0,
          "Name": "tv",
          "ProfileId": "1",
          "RootFolder": "",
          "Tags": [],
          "LanguageId": "1",
          "UseSeasonFolders": true,
          "SeriesType": "standard"
        }
      ],
      "SearchNewRequests": true,
      "MonitorNewRequests": true,
      "UseSSL": false,
      "Version": "4"
    }
  },
  "BotClient": {
    "Client": ""
  },
  "Movies": {
    "Client": "Disabled"
  },
  "TvShows": {
    "Client": "Disabled",
    "Restrictions": "None"
  },
  "Port": $port,
  "BaseUrl" : "/requestrr",
  "DisableAuthentication": false,
  "Version": "2.1.1"
}
CFG

    echo "Requestrr config applied."

    echo "Installing Systemd service"
    cat > $HOME/.config/systemd/user/requestrr.service << EOF
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
WantedBy=default.target
EOF

    cat > $HOME/Requestrr/appsettings.json << SET
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
    if [[ ! -f $HOME/.install/.requestrr.lock ]]; then
        port=$(_port 1000 18000)
        _requestrr_download
        unzip -q "$HOME/.tmp/requestrr.zip" -d $HOME/ >> ${log} 2>&1
        rm -rf "$HOME/.tmp/requestrr.zip"
        mkdir -p "$HOME/Requestrr"
        mv $HOME/requestrr*/* "$HOME/Requestrr"
        rm -rf $HOME/requestrr*/
        echo "archive extracted."
        chmod u+x "$HOME/Requestrr/Requestrr.WebApi"
        find "$HOME/Requestrr" -type d -print -exec chmod 755 {} \; >> ${log} 2>&1
        echo "Requestrr permissions set"
        mkdir -p "$HOME/.config/Requestrr/"
        mkdir -p "$HOME/.config/systemd/user/"
        echo "Configuring "
        _write_configs
        systemctl --user -q enable --now requestrr >> ${log} 2>&1
        touch $HOME/.install/.requestrr.lock
        echo "Requestrr service installed and enabled"
        echo "Requestrr is available at http://$(hostname):$port/requestrr; Secure your installation manually through the web interface."
    else
        echo "requestrr is already installed."
    fi
}

function _remove() {
    systemctl --user disable --now requestrr
    sleep 2
    rm -rf $HOME/Requestrr
    rm -rf $HOME/.config/Requestrr
    rm -rf $HOME/.config/systemd/user/requestrr.service
    rm -rf $HOME/.install/.requestrr.lock
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
