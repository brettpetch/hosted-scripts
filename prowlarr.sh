#!/bin/bash
## Installer by b
## Thanks to Bakerboy, Sosig, Liara, and team for some of the functions / logic.
## b

user=$(whoami)

if [[ ! -d /home/$user/.logs ]]; then
    mkdir -p /home/${user}/.logs/
fi

touch /home/${user}/.logs/prowlarr.log
log="/home/${user}/.logs/prowlarr.log"

function port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq ${LOW_BOUND} ${UPPER_BOUND} | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function _install() {
    ssl_port=$(port 14000 16000)
    port=$(port 10000 14000)

    # Download App
    curl -sL "http://prowlarr.servarr.com/v1/update/develop/updatefile?os=linux&runtime=netcore&arch=x64" -o /tmp/prowlarr.tar.gz >> "$log" 2>&1 || {
        echo "Download failed."
        exit 1
    }

    # Extract
    tar xfv "/tmp/prowlarr.tar.gz" --directory /home/${user}/ >> "$log" 2>&1 || {
        echo_error "Failed to extract"
        exit 1
    }
    rm -rf /tmp/prowlarr.tar.gz

    if [[ ! -d /home/$user/.config/systemd/user/ ]]; then
        mkdir -p /home/$user/.config/systemd/user/
    fi

    # Service File
    cat > "/home/$user/.config/systemd/user/prowlarr.service" << EOF
[Unit]
Description=Prowlarr Daemon
After=syslog.target network.target

[Service]
Type=simple
ExecStart=/home/$user/Prowlarr/Prowlarr -nobrowser -data=/home/$user/.config/prowlarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    mkdir -p /home/$user/.config/prowlarr/
    cat > /home/$user/.config/prowlarr/config.xml << PROWLARR
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
PROWLARR

    # Enable/Start Prowlarr
    systemctl enable --now --user prowlarr.service
    
    domain=$(hostname -f)

    echo "Prowlarr has been installed. You can access it at http://${domain}:${port}"
    echo "Remember to setup authentication. This is publicly accessible and will contain your API keys and stuff."
}

function _remove() {
    systemctl disable --now --user prowlarr
    rm -rf ~/.config/prowlarr/
    rm -rf ~/Prowlarr/
    echo "Prowlarr has been removed."
}

echo "Welcome to Prowlarr installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "install = Install Prowlarr"
echo "uninstall = Completely removes Prowlarr"
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
