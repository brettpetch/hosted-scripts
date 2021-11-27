#!/bin/bash
# By B
user=$(whoami)
mkdir -p ~/.logs/
touch ~/.logs/lounge.log
log="$HOME/.logs/race-ready.log"
port=$(grep 'WebUI\\Port' /home/${user}/.config/qBittorrent/qBittorrent.conf | cut -d= -f2)
subnet=$(cat /install/subnet.lock)

function _nvm() {
    if [[ ! -d /home/$user/.nvm ]]; then
        echo "Installing NVM and Node..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash >> "$log" 2>&1
        export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
        nvm install --lts >> "$log" 2>&1 || {
            echo "Node failed to install"
            exit 1
        }
        echo "Node installed."
    else
        echo "Node is already installed."
    fi
}

function qbit_race() {
    _nvm
    echo "Installing qbit-race"
    mkdir -p "/home/${user}/scripts"
    RACE_DIR="/home/${user}/scripts/qbit-race"
    git clone https://github.com/ckcr4lyf/qbit-race.git "${RACE_DIR}" >> "$log" 2>&1
    cp "${RACE_DIR}/sample.env" "${RACE_DIR}/.env"
    sed -i 's|QBIT_HOST=127.0.0.1|QBIT_HOST=${subnet}|g' "${RACE_DIR}/.env"
    sed -i 's|QBIT_PORT=8080|QBIT_PORT=${port}|g' "${RACE_DIR}/.env"
    cp "${RACE_DIR}/sample.settings.js" "${RACE_DIR}/settings.js"
    sed -i 's|CONCURRENT_RACES: 1,|CONCURRENT_RACES: 3,|g' "${RACE_DIR}/settings.js"
    sed -i 's|REANNOUNCE_INTERVAL: 5000,|REANNOUNCE_INTERVAL: 7000,|g' "${RACE_DIR}/settings.js"
    npm --prefix "${RACE_DIR}" install "${RACE_DIR}" >> "$log" 2>&1
    touch ~/.install/.qbit-race.lock
}

function nightwalker() {
    git clone "https://github.com/brettpetch/nightwalker.git" /home/${user}/scripts/nightwalker >> "$log" 2>&1
    sudo box stop qbittorrent
    sed -i 's|WebUI\\RootFolder=.*|WebUI\\RootFolder=/home/${user}/scripts/nightwalker/|g' /home/${user}/.config/qBittorrent/qBittorrent.conf
    sudo box start qbittorrent
    touch ~/.install/.nightwalker.lock
}

echo "Welcome to The Lounge installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "node = Install Node."
echo "qbitrace = Installs qbit-race + node"
echo "nightwalker = Installs nightwalker"
echo "brr = Installs qbitrace & nightwalker options."
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "node")
            _nvm
            _install
            _systemd
            _adduser
            break
            ;;
        "qbitrace")
            qbit_race
            break
            ;;
        "nightwalker")
            nightwalker
            break
            ;;
        "brr")
            qbit_race
            nightwalker
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
