#!/bin/bash
# By B
user=$(whoami)
mkdir -p /home/${user}/.logs/
touch /home/${user}/.logs/race-ready.log
log="/home/${user}/.logs/race-ready.log"
port=$(grep 'WebUI\\Port' /home/${user}/.config/qBittorrent/qBittorrent.conf | cut -d= -f2)
subnet=$(cat /home/${user}/.install/subnet.lock)

function github_latest_version() {
    # Function by Liara
    # Argument expects the author/repo format
    # e.g. swizzin/swizzin
    repo=$1
    curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/${repo}/releases/latest | grep -o '[^/]*$'
}

function _nvm() {
    ## Function for installing nvm.
    if [[ ! -d /home/$user/.nvm ]]; then
        echo "Installing node"
        nvmVersion=$(github_latest_version "nvm-sh/nvm")
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${nvmVersion}/install.sh | bash >> "$log" 2>&1
        echo "nvm installed."
    else
        echo "nvm is already installed."
    fi
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
    nvm install --lts >> "$log" 2>&1 || {
        echo "node failed to install"
        exit 1
    }
    echo "Node LTS installed."
}

function qbit_race() {
    _nvm
    . /home/${user}/.bashrc
    echo "Installing qbit-race"
    RACE_DIR="/home/${user}/scripts/qbit-race"
    mkdir -p "${RACE_DIR}"

    version=$(github_latest_version ckcr4lyf/qbit-race)
    curl -sL "https://github.com/ckcr4lyf/qbit-race/archive/refs/tags/${version}.tar.gz" -o /tmp/qbit-race.tar.gz
    tar xvf "/tmp/qbit-race.tar.gz" --directory "${RACE_DIR}" --strip-components=1 >> "$log" 2>&1
    rm -f /tmp/qbit-race.tar.gz
   
    cp "${RACE_DIR}/sample.env" "${RACE_DIR}/.env"
    sed -i "s|QBIT_HOST=127.0.0.1|QBIT_HOST=${subnet}|g" "${RACE_DIR}/.env"
    sed -i "s|QBIT_PORT=8080|QBIT_PORT=${port}|g" "${RACE_DIR}/.env"
    cp "${RACE_DIR}/sample.settings.js" "${RACE_DIR}/settings.js"
    sed -i 's|REANNOUNCE_INTERVAL: 5000,|REANNOUNCE_INTERVAL: 7000,|g' "${RACE_DIR}/settings.js"
    sed -i 's|CONCURRENT_RACES: 1,|CONCURRENT_RACES: 3,|g' "${RACE_DIR}/sample.settings.js"
    npm --prefix "${RACE_DIR}" install "${RACE_DIR}" >> "$log" 2>&1 || {
        echo "Could not install dependencies. Please check the logs and consult the community support channel for your vendor."
        exit 1
    }
    echo "Your script path is $(which node)"
    echo "Your script argument is '${RACE_DIR}/bin/autodl_feed.js \"\$(InfoHash)\" \"\$(InfoName)\" \"\$(Tracker)\" \"\$(TorrentPathName)\"'"
    echo "Your post-script is '$(which node) ${RACE_DIR}/bin/post_race.js \"%I\" \"%N\" \"%T\"'"
    echo "qbit-race has been installed."
    touch ~/.install/.qbit-race.lock
}

function nightwalker() {
    echo "Cloning Nightwalker Repo"
    git clone "https://github.com/brettpetch/nightwalker.git" /home/${user}/scripts/nightwalker >> "$log" 2>&1 || {
        echo "Failed to clone nightwalker... Exiting."
        exit 1
    }
    echo "Nightwalker cloned."
    sudo box stop qbittorrent
    sed -i "s|^.*AlternativeUIEnabled.*|WebUI\AlternativeUIEnabled=true|g" /home/${user}/.config/qBittorrent/qBittorrent.conf
    sed -i "s|^.*RootFolder.*|WebUI\\\RootFolder=/home/${user}/scripts/nightwalker/|g" /home/${user}/.config/qBittorrent/qBittorrent.conf
    sudo box start qbittorrent
    touch ~/.install/.nightwalker.lock
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

echo "Welcome to qbit-race installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "node = Install Node."
echo "qbitrace = Installs qbit-race + node (Depreciated/Unsupported)"
echo "nightwalker = Installs nightwalker"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "node")
            _nvm
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
        "exit")
            break
            ;;
        *)
            echo "Unknown Option."
            ;;
    esac
done
exit
