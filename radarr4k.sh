#!/bin/bash
user=$(whoami)
mkdir -p "/home/$user/.logs/"
touch "/home/$user/.logs/radarr4k.log"
log="/home/$user/.logs/radarr4k.log"

function port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq "${LOW_BOUND}" "${UPPER_BOUND}" | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function _install() { 
    if [[ ! -f "/home/$user/.install/.radarr.lock" ]]; then
        echo "Radarr is not installed. Exiting..."
        exit 1
    fi
    mkdir -p "/home/$user/.config/systemd/user/"
    mkdir -p "/home/$user/.config/Radarr4k/"
    echo "Installing the service"
    cat > "/home/$user/.config/systemd/user/radarr4k.service" << SERV
[Unit]
Description=Radarr4k
After=syslog.target network.target

[Service]
Type=simple
Environment="TMPDIR=%h/.tmp"
ExecStart=%h/Radarr/Radarr -nobrowser -data=%h/.config/Radarr4k
TimeoutStopSec=20
KillMode=process
Restart=on-failure
WorkingDirectory=%h

[Install]
WantedBy=default.target
SERV
    port=$(port 12000 14000)
echo "Installing Configuration"
    cat > "/home/$user/.config/Radarr4k/config.xml" << EOF
<Config>
  <Port>${port}</Port>
  <UrlBase></UrlBase>
  <BindAddress>*</BindAddress>
  <SslPort>8787</SslPort>
  <EnableSsl>False</EnableSsl>
  <LogLevel>Info</LogLevel>
  <Branch>develop</Branch>
  <LaunchBrowser>False</LaunchBrowser>
  <UpdateMechanism>BuiltIn</UpdateMechanism>
  <AnalyticsEnabled>False</AnalyticsEnabled>
  <SslCertPath></SslCertPath>
  <AuthenticationMethod>None</AuthenticationMethod>
</Config>
EOF
echo "Starting the userland service."
    systemctl enable --user --now -q radarr4k
    sleep 45
    apikey=$(grep -oPm1 "(?<=<ApiKey>)[^<]+" /home/"$user"/.config/Radarr4k/config.xml)
    if ! timeout 45 bash -c -- "while ! curl -fL \"http://127.0.0.1:${port}/api/v3/system/status?apiKey=${apikey}\" >> \"$log\" 2>&1; do sleep 5; done"; then
        echo "Radarr API did not respond as expected. Please make sure Radarr is on v3 and running."
        exit 1
    fi
    read -rep "Please set a password for your radarr4k user ${user}> " -i "" password
    echo "Applying authentication"
    payload=$(curl -sL "http://127.0.0.1:${port}/api/v3/config/host?apikey=${apikey}" | jq ".authenticationMethod = \"forms\" | .username = \"${user}\" | .password = \"${password}\"")
    curl -s "http://127.0.0.1:${port}/api/v3/config/host?apikey=${apikey}" -X PUT -H 'Accept: application/json, text/javascript, */*; q=0.01' --compressed -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' --data-raw "${payload}" >> "$log"
    sleep 15
    echo "Restarting Radarr4k"
    systemctl restart --user radarr4k
    echo "Now up and running at http://$(hostname -f):${port}"
    mkdir -p "/home/${user}/.install/"
    touch "/home/${user}/.install/.radarr4k.lock"
}

function _remove {
    systemctl stop --user radarr4k
    systemctl disable --user radarr4k
    rm -rf "/home/$user/.config/Radarr4k"
    rm "/home/$user/.config/systemd/user/radarr4k.service"
    rm "/home/${user}/.install/.radarr4k.lock"
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

echo "Welcome to The Radarr 4K installer..."
echo ""
echo "What do you like to do?"
echo "install = Install Radarr 4K"
echo "uninstall = Completely removes Radarr 4K"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            if [[ -f "/home/$user/.install/.radarr4k.lock" ]]; then
                echo "Radarr 4K is already installed."
            else
                _install
            fi
            break
            ;;
        "uninstall")
            if [[ ! -f "/home/$user/.install/.radarr4k.lock" ]]; then
                echo "Radarr 4K is not installed."
                break
            else
                _remove
            fi
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
