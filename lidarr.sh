#!/bin/bash
# Lidarr .NET Core Migration Script

app=lidarr

if [[ ! -d $HOME/.logs ]]; then
    mkdir -p $HOME/.logs
fi

touch "$HOME/.logs/$app.log"
log="$HOME/.logs/$app.log"

function _upgrade() {

    if [[ ! -f $HOME/.install/.lidarr.lock ]]; then
        echo "Lidarr not installed. Exiting"
        exit 1
    fi
    
    echo "Stopping old install"

    sudo box disable lidarr
    sudo box stop lidarr
    
    echo "Removing old Lidarr Install"
    rm -rf "$HOME/Lidarr"
    # Download App
    echo "Downloading Lidarr"
    
    mkdir -p "$HOME/.tmp/"

    curl -sL "http://lidarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64" -o "$HOME/.tmp/lidarr.tar.gz" >> "$log" 2>&1 || {
        echo "Download failed."
        exit 1
    }

    # Extract
    echo "Extracting Lidarr"
    tar xfv "$HOME/.tmp/lidarr.tar.gz" --directory $HOME/ >> "$log" 2>&1 || {
        echo_error "Failed to extract"
        exit 1
    }
    rm -rf "$HOME/.tmp/lidarr.tar.gz"

    if [[ ! -d $HOME/.config/systemd/user/ ]]; then
        mkdir -p $HOME/.config/systemd/user/
    fi

    # Service File
    echo "Writing service file"
    cat > "$HOME/.config/systemd/user/lidarr.service" << EOF
[Unit]
Description=Lidarr Daemon
After=syslog.target network.target
[Service]
Type=simple
Environment="TMPDIR=$HOME/.tmp"
EnvironmentFile=$HOME/.install/.lidarr.lock
ExecStart=$HOME/Lidarr/Lidarr -nobrowser -data=$HOME/.config/Lidarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure
[Install]
WantedBy=default.target
EOF

    # Enable/Start Prowlarr
    echo "Starting Lidarr"
    systemctl enable --now --user lidarr
    
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

echo "Welcome to Lidarr .NET Core Migration Script..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "upgrade = Upgrade Lidarr"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
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
