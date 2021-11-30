#!/bin/bash
# Thx liara, userdocs 
username=$(whoami)
mkdir -p "/home/${username}/.logs/"
export log="/home/${username}/.logs/filebrowser.log"
touch "$log"
function _port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq "${LOW_BOUND}" "${UPPER_BOUND}" | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}
function create_self_ssl() {
    user=$1
    if [[ ! -f /home/$user/.ssl/$user-self-signed.key ]]; then
        echo "Generating self-signed key for $user"
        mkdir -p "/home/$user/.ssl"
        country=US
        state=California
        locality="San Fransisco"
        organization=swizzin
        organizationalunit=$user
        commonname=$user
        ssl_password=""

        openssl genrsa -out "/home/$user/.ssl/$user-self-signed.key" 2048 >> /dev/null 2>&1
        openssl req -new -key "/home/$user/.ssl/$user-self-signed.key" -out "/home/$user/.ssl/$user-self-signed.csr" -passin pass:"$ssl_password" -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname" >> /dev/null 2>&1
        openssl x509 -req -days 1095 -in "/home/$user/.ssl/$user-self-signed.csr" -signkey "/home/$user/.ssl/$user-self-signed.key" -out "/home/$user/.ssl/$user-self-signed.crt" >> /dev/null 2>&1
        chown -R "$user": "/home/$user/.ssl"
        chmod 750 "/home/$user/.ssl"
        echo_progress_done "Key for $user generated"
    fi
}

read -rep "Please set a password for filebrowser: " -i "$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c10)" password

app_port_http=$(_port 10001 20000)

mkdir -p "/home/${username}/bin"
mkdir -p "/home/${username}/.config/Filebrowser"

wget -O "/home/${username}/filebrowser.tar.gz" "$(curl -sNL https://api.github.com/repos/filebrowser/filebrowser/releases/latest | grep -Po 'ht(.*)linux-amd64(.*)gz')" >> "$log" 2>&1
tar -xvzf "/home/${username}/filebrowser.tar.gz" --exclude LICENSE --exclude README.md --exclude CHANGELOG.md -C "/home/${username}/bin" >> "$log" 2>&1

rm -f "/home/${username}/filebrowser.tar.gz" >> "$log" 2>&1
echo "Initialising database and configuring Filebrowser"
create_self_ssl "${username}"

"/home/${username}/bin/filebrowser" config init -d "/home/${username}/.config/Filebrowser/filebrowser.db" >> "$log" 2>&1

"/home/${username}/bin/filebrowser" config set -t "/home/${username}/.ssl/${username}-self-signed.crt" -k "/home/${username}/.ssl/${username}-self-signed.key" -d "/home/${username}/.config/Filebrowser/filebrowser.db" >> "$log" 2>&1
"/home/${username}/bin/filebrowser" config set -a 0.0.0.0 -p "${app_port_http}" -l "/home/${username}/.config/Filebrowser/filebrowser.log" -d "/home/${username}/.config/Filebrowser/filebrowser.db" >> "$log" 2>&1
"/home/${username}/bin/filebrowser" users add "${username}" "${password}" --perm.admin -d "/home/${username}/.config/Filebrowser/filebrowser.db" >> "$log" 2>&1

chown "${username}.${username}" -R "/home/${username}/bin" > /dev/null 2>&1
chown "${username}.${username}" -R "/home/${username}/.config" > /dev/null 2>&1
chmod 700 "/home/${username}/bin/filebrowser" > /dev/null 2>&1
mkdir -p "/home/$username/.config/systemd/user"
cat > "/home/$username/.config/systemd/user/filebrowser.service" <<- SERVICE
	[Unit]
	Description=filebrowser
	After=network.target
	[Service]
	UMask=002
	Type=simple
	WorkingDirectory=/home/${username}
	ExecStart=/home/${username}/bin/filebrowser -d /home/${username}/.config/Filebrowser/filebrowser.db
	TimeoutStopSec=20
	KillMode=process
	Restart=always
	RestartSec=2
	[Install]
	WantedBy=multi-user.target
SERVICE

systemctl --user enable --now filebrowser
echo "Systemd service installed"
touch "/home/${username}/.install/.filebrowser.lock"
echo "Filebrowser us up and running at https://$(hostname -f):${app_port_http}/filebrowser"
