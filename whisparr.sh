#!/bin/bash
## Installer by b
## Thanks to Bakerboy, Sosig, Liara, and team for some of the functions / logic.

user=$(whoami)

if [[ ! -d $HOME/.logs ]]; then
    mkdir -p $HOME/.logs
fi

touch "$HOME/.logs/whisparr.log"
log="$HOME/.logs/whisparr.log"

function port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq ${LOW_BOUND} ${UPPER_BOUND} | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function _install() {
    ssl_port=$(port 14000 16000)
    port=$(port 8000 13000)
    domain=$(hostname -f)

    # Download App
    echo "Downloading Whisparr"
    
    mkdir -p "$HOME/.tmp"
    
    curl -sL "http://whisparr.servarr.com/v1/update/nightly/updatefile?os=linux&runtime=netcore&arch=x64" -o $HOME/.tmp/whisparr.tar.gz >> "$log" 2>&1 || {
        echo "Download failed."
        exit 1
    }

    # Extract
    echo "Extracting Whisparr"
    tar xfv "$HOME/.tmp/whisparr.tar.gz" --directory $HOME/ >> "$log" 2>&1 || {
        echo_error "Failed to extract"
        exit 1
    }
    rm -rf /tmp/whisparr.tar.gz

    if [[ ! -d $HOME/.config/systemd/user/ ]]; then
        mkdir -p $HOME/.config/systemd/user/
    fi

    # Service File
    echo "Writing service file"
    cat > "$HOME/.config/systemd/user/whisparr.service" << EOF
[Unit]
Description=Whisparr Daemon
After=syslog.target network.target

[Service]
Type=simple
ExecStart=$HOME/Whisparr/Whisparr -nobrowser -data=$HOME/.config/Whisparr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=default.target
EOF
    mkdir -p $HOME/.config/Whisparr/
    cat > $HOME/.config/Whisparr/config.xml << WHISPARR
<Config>
  <LogLevel>debug</LogLevel>
  <UpdateMechanism>BuiltIn</UpdateMechanism>
  <BindAddress>*</BindAddress>
  <Port>${port}</Port>
  <SslPort>${ssl_port}</SslPort>
  <EnableSsl>False</EnableSsl>
  <LaunchBrowser>False</LaunchBrowser>
  <ApiKey></ApiKey>
  <AuthenticationMethod>None</AuthenticationMethod>
  <UrlBase></UrlBase>
  <Branch>develop</Branch>
</Config>
WHISPARR

    # Enable/Start Whisparr
    echo "Starting Whisparr"
    systemctl enable --now --user whisparr.service
    touch "$HOME/.install/.whisparr.lock"
    
    echo "Whisparr has been installed. You can access it at http://${domain}:${port}"
    echo "Remember to check your authentication. This is publicly accessible and will contain your API keys and stuff."
}

function _remove() {
    systemctl disable --now --user whisparr
    rm -rf "$HOME/.config/Whisparr/"
    rm -rf "$HOME/Whisparr/"
    echo "Whisparr has been removed."
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

echo "Welcome to Whisparr installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "install = Install Whisparr"
echo "uninstall = Completely removes Whisparr"
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
