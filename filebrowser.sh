#!/bin/bash
# Thx liara, userdocs 
username=$(whoami)
mkdir -p "$HOME/.logs/"
export log="$HOME/.logs/filebrowser.log"
touch "$log"

function _port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq "${LOW_BOUND}" "${UPPER_BOUND}" | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function create_self_ssl() {
    user=$1
    if [[ ! -f $HOME/.ssl/$user-self-signed.key ]]; then
        echo "Generating self-signed key for $user"
        mkdir -p "$HOME/.ssl"
        country=US
        state=California
        locality="San Fransisco"
        organization=swizzin
        organizationalunit=$user
        commonname=$user
        ssl_password=""

        openssl genrsa -out "$HOME/.ssl/$user-self-signed.key" 2048 >> /dev/null 2>&1
        openssl req -new -key "$HOME/.ssl/$user-self-signed.key" -out "$HOME/.ssl/$user-self-signed.csr" -passin pass:"$ssl_password" -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname" >> /dev/null 2>&1
        openssl x509 -req -days 1095 -in "$HOME/.ssl/$user-self-signed.csr" -signkey "$HOME/.ssl/$user-self-signed.key" -out "$HOME/.ssl/$user-self-signed.crt" >> /dev/null 2>&1
        chown -R "$user": "$HOME/.ssl"
        chmod 750 "$HOME/.ssl"
        echo "Key for $user generated"
    fi
}
function _install() {
    read -rep "Please set a password for filebrowser: " -i "$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c10)" password

    app_port_http=$(_port 10001 20000)

    mkdir -p "$HOME/bin"
    mkdir -p "$HOME/.config/Filebrowser"

    wget -O "$HOME/filebrowser.tar.gz" "$(curl -sNL https://api.github.com/repos/filebrowser/filebrowser/releases/latest | grep -Po 'ht(.*)linux-amd64(.*)gz')" >> "$log" 2>&1
    tar -xvzf "$HOME/filebrowser.tar.gz" --exclude LICENSE --exclude README.md --exclude CHANGELOG.md -C "$HOME/bin" >> "$log" 2>&1

    rm -f "$HOME/filebrowser.tar.gz" >> "$log" 2>&1
    echo "Initialising database and configuring Filebrowser"
    create_self_ssl "${username}"

    "$HOME/bin/filebrowser" config init -d "$HOME/.config/Filebrowser/filebrowser.db" >> "$log" 2>&1

    "$HOME/bin/filebrowser" config set -t "$HOME/.ssl/${username}-self-signed.crt" -k "$HOME/.ssl/${username}-self-signed.key" -d "$HOME/.config/Filebrowser/filebrowser.db" >> "$log" 2>&1
    "$HOME/bin/filebrowser" config set -a 0.0.0.0 -p "${app_port_http}" -l "$HOME/.config/Filebrowser/filebrowser.log" -d "$HOME/.config/Filebrowser/filebrowser.db" >> "$log" 2>&1
    "$HOME/bin/filebrowser" users add "${username}" "${password}" --perm.admin -d "$HOME/.config/Filebrowser/filebrowser.db" >> "$log" 2>&1

    chown "${username}.${username}" -R "$HOME/bin" > /dev/null 2>&1
    chown "${username}.${username}" -R "$HOME/.config" > /dev/null 2>&1
    chmod 700 "$HOME/bin/filebrowser" > /dev/null 2>&1
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/filebrowser.service" <<- SERVICE
[Unit]
Description=filebrowser
After=network.target
[Service]
UMask=002
Type=simple
WorkingDirectory=$HOME
ExecStart=$HOME/bin/filebrowser -d $HOME/.config/Filebrowser/filebrowser.db
TimeoutStopSec=20
KillMode=process
Restart=always
RestartSec=2
[Install]
WantedBy=default.target
SERVICE

    systemctl --user enable --now filebrowser
    echo "Systemd service installed"
    touch "$HOME/.install/.filebrowser.lock"
    echo "Filebrowser us up and running at https://$(hostname -f):${app_port_http}/"
}

function _upgrade() {
    echo "Stopping Filebrowser"
    systemctl --user stop filebrowser
    echo "Backing up Filebrowser"
    mv $HOME/bin/filebrowser $HOME/bin/filebrowser.bak
    echo "Downloading new release"
    wget -O "$HOME/filebrowser.tar.gz" "$(curl -sNL https://api.github.com/repos/filebrowser/filebrowser/releases/latest | grep -Po 'ht(.*)linux-amd64(.*)gz')" >> "$log" 2>&1
    echo "Extracting new release"
    tar -xvzf "$HOME/filebrowser.tar.gz" --exclude LICENSE --exclude README.md --exclude CHANGELOG.md -C "$HOME/bin" >> "$log" 2>&1
    rm -f "$HOME/filebrowser.tar.gz" >> "$log" 2>&1
    chmod 700 "$HOME/bin/filebrowser"
    if [[ -f $HOME/bin/filebrowser ]]; then
        rm $HOME/bin/filebrowser.bak
    else
        echo "Something went wrong during the upgrade, reverting changes"
        mv $HOME/bin/filebrowser.bak $HOME/bin/filebrowser
    fi
    echo "Restarting Filebrowser"
    systemctl restart filebrowser
    echo "Done."
}

function _remove() {
    systemctl --user stop filebrowser
    systemctl --user disable filebrowser
    rm -rf "$HOME/.config/Filebrowser"
    rm -rf "$HOME/.config/systemd/user/filebrowser.service"
    rm -f "$HOME/.install/.filebrowser.lock"
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

echo "Welcome to Filebrowser installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "install = Install Filebrowser"
echo "upgrade = Upgrades Filebrowser"
echo "uninstall = Completely removes Filebrowser"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            _install
            break
            ;;
        "upgrade")
            _upgrade
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
