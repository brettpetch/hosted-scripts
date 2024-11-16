#!/bin/bash
user=$(whoami)
mkdir -p "/home/$user/.logs/"
touch "/home/$user/.logs/sonarr4k.log"
log="/home/$user/.logs/sonarr4k.log"

function port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq ${LOW_BOUND} ${UPPER_BOUND} | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function _systemd() {
    cat > /home/${USER}/.config/systemd/user/sonarr4k.service << SERVICE
[Unit]
Description=Sonarr4k
After=syslog.target network.target

[Service]
Type=simple
Environment="TMPDIR=%h/.tmp"
ExecStart=%h/Sonarr/Sonarr -nobrowser -data=%h/.config/Sonarr4k
WorkingDirectory=%h
Restart=on-failure

[Install]
WantedBy=default.target
SERVICE

}
function _install() {
    if [[ ! -f "/home/$user/.install/.sonarr.lock" ]]; then
        echo "Sonarr is not installed. Exiting..."
        exit 1
    fi
    mkdir -p /home/$user/.config/systemd/user/
    mkdir -p /home/$user/.config/Sonarr4k/
    port=$(port 8000 11000)
    _systemd
    
    cat > /home/$user/.config/Sonarr4k/config.xml << EOF
<Config>
  <LogLevel>info</LogLevel>
  <EnableSsl>False</EnableSsl>
  <Port>${port}</Port>
  <SslPort>9898</SslPort>
  <UrlBase></UrlBase>
  <BindAddress>*</BindAddress>
  <AuthenticationMethod>None</AuthenticationMethod>
  <UpdateMechanism>BuiltIn</UpdateMechanism>
  <Branch>main</Branch>
  <LaunchBrowser>False</LaunchBrowser>
  <SslCertHash></SslCertHash>
</Config>
EOF
    systemctl enable --user --now -q sonarr4k
    sleep 45
    apikey=$(grep -oPm1 "(?<=<ApiKey>)[^<]+" /home/"$user"/.config/Sonarr4k/config.xml)
    if ! timeout 45 bash -c -- "while ! curl -fL \"http://127.0.0.1:${port}/api/v3/system/status?apiKey=${apikey}\" >> \"$log\" 2>&1; do sleep 5; done"; then
        echo "Sonarr API did not respond as expected. Please make sure Sonarr is on v3 and running."
        exit 1
    fi
    read -rep "Please set a password for your sonarr4k user ${user}> " -i "" password
    payload=$(curl -sL "http://127.0.0.1:${port}/api/v3/config/host?apikey=${apikey}" | jq ".authenticationMethod = \"forms\" | .username = \"${user}\" | .password = \"${password}\"")
    curl -s "http://127.0.0.1:${port}/api/v3/config/host?apikey=${apikey}" -X PUT -H 'Accept: application/json, text/javascript, */*; q=0.01' --compressed -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' --data-raw "${payload}" >> "$log"
    sleep 15
    systemctl restart --user sonarr4k
    echo "Now up and running at http://$(hostname -f):${port}"
    mkdir -p "/home/${user}/.install/"
    touch "/home/${user}/.install/.sonarr4k.lock"
}

function _remove {
    systemctl stop --user sonarr4k
    systemctl disable --user sonarr4k
    rm -rf /home/$user/.config/Sonarr4k
    rm /home/$user/.config/systemd/user/sonarr4k.service
    rm "/home/${user}/.install/.sonarr4k.lock"
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

echo "Welcome to The Sonarr 4K installer..."
echo ""
echo "What do you like to do?"
echo "install = Install Sonarr 4K"
echo "uninstall = Completely removes Sonarr 4K"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            if [[ -f "/home/$user/.install/.sonarr4k.lock" ]]; then
                echo "Sonarr 4K is already installed."
            else
                _install
            fi
            break
            ;;
        "upgrade")
            if [[ -f "/home/$user/.install/.sonarr4k.lock" ]]; then
                echo "Upgrading Sonarr 4K systemd"
                _systemd
                systemctl --user daemon-reload
                systemctl --user try-restart sonarr4k
            else
                echo "Sonarr 4K is not installed"
                break
            fi
            ;;
        "uninstall")
            if [[ ! -f "/home/$user/.install/.sonarr4k.lock" ]]; then
                echo "Sonarr 4K is not installed."
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
