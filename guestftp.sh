#!/bin/bash
# Refactored from the WalkerServers GuestFTP script by b.
username=$(whoami)
user=$1
pw=$2
dir=$3

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

if [[ -z $1 || -z $2 || -z $3 ]]; then echo "You must define a username, password and path (in that order)!"; exit 1; fi

venv="/home/${username}/.config/venv/guestftp"

## Make venv
mkdir -p /home/${username}/.config/venv/
python3 -m venv ${venv}

## Ensure pip is updated to fix rust error
${venv}/bin/pip install --upgrade pip

# Install pyftpdlib and deps

${venv}/bin/pip install wheel
${venv}/bin/pip install pyOpenSSL
${venv}/bin/pip install pyftpdlib

function port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq ${LOW_BOUND} ${UPPER_BOUND} | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

# Install script

mkdir -p /home/${username}/.config/guest-ftp
cd /home/${username}/.config/guest-ftp
port=$(port 3000 16200)
cat <<EOF >> /home/${username}/.config/guest-ftp/ftpserver.py
import logging

from pyftpdlib.authorizers import DummyAuthorizer
from pyftpdlib.handlers import TLS_FTPHandler
from pyftpdlib.servers import FTPServer


# The port the FTP server will listen on.
# This must be greater than 1023 unless you run this script as root.
FTP_PORT = $port

# The name of the FTP user that can log in.
FTP_USER = "$user"

# The FTP user's password.
FTP_PASSWORD = "$pw"

# The directory the FTP user will have full read/write access to.
FTP_DIRECTORY = "$dir"


def main():
    authorizer = DummyAuthorizer()

    # Define a new user having read only permissions.
    authorizer.add_user(FTP_USER, FTP_PASSWORD, FTP_DIRECTORY, perm='elr')

    handler = TLS_FTPHandler
    handler.certfile = '/home/${username}/.config/guest-ftp/key.pem'
    handler.authorizer = authorizer
    handler.permit_foreign_addresses = True

    # Define logging
    logging.basicConfig(filename='/home/${username}/.config/guest-ftp/ftpserver.log', level=logging.INFO)

    # Define a customized banner (string returned when client connects)
    handler.banner = "ftpd managed by beeboo."

    # Optionally specify range of ports to use for passive connections.
    handler.passive_ports = range(60000, 65535)

    address = ('', FTP_PORT)
    server = FTPServer(address, handler)

    server.max_cons = 256

    server.serve_forever()


if __name__ == '__main__':
    main()
EOF

# Make cert for login

openssl genrsa -out server.key 2048
openssl rsa -in server.key -out server.key
openssl req -sha256 -new -key server.key -out server.csr -subj "/CN=$(hostname -f)"
openssl x509 -req -sha256 -days 365 -in server.csr -signkey server.key -out server.crt
cat server.crt server.key > key.pem
chmod 777 key.pem

## Set permission
chown -R ${username}: /home/${username}/.config/guest-ftp/ftpserver.py

# Adding systemd file
mkdir -p /home/${username}/.config/systemd/user/
cat <<EOF >>/home/${username}/.config/systemd/user/guest-ftp.service
[Unit]
Description=Guest FTPD Service
After=network.target

[Service]
Type=simple
ExecStart=${venv}/bin/python3 /home/${username}/.config/guest-ftp/ftpserver.py
WorkingDirectory=/home/${username}/.config/guest-ftp/

[Install]
WantedBy=default.target
EOF

## Enable and start systemd

systemctl --user daemon-reload
systemctl enable --user --now guest-ftp.service

echo "GuestFTP will run on port $port"
echo "Done installing guest ftp"
