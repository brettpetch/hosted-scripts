#!/bin/bash
# Maintainer: Brett Petch
# For Swizzin.net / HostingByDesign - NOT EVER for Dedicated Servers.
# Only use on shared slots.
# Licensed under GNU General Public License v3.0
# Logs stored at $HOME/.logs/migration.log
mkdir -p "$HOME/.logs/"
export log="$HOME/.logs/migration.log"
touch "$log"

function new_port() {
    # Liara Get Free Port Between Range
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq ${LOW_BOUND} ${UPPER_BOUND} | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function get_ini() {
    # Get value from ini file with [sections]
    # Saves several braincells and makes code far more readable
    file=$1
    section=$2
    param=$3
    sed -nr "/^\[${section}\]/ { :l /^${param}[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" "${file}"
}

function set_ini() {
    # Sets or appends if not exists within [sections]
    # Saves several braincells and makes code far more readable
    file=$1
    section=$2
    param=$3
    newval=$4
    if [[ -z $(get_ini "${file}" "${section}" "${param}") ]]; then
      sed -i "/^\[${section}\]/a ${param} = ${newval}" "${file}"
    else
      sed -i "/^\[${section}\]\$/,/^\[/ s/^${param}.*/${param} = ${newval}/" "${file}"
    fi
}

function get_attr() {
    file=$1
    param=$2
    grep -Pio "${param}=*\"\K[^\"]*" "$HOME/.plex/config/Library/Application Support/Plex Media Server/Preferences.xml.bak"
}

function set_attr() {
    file=$1
    param=$2
    set=$3
    sed -i "s|$(get_attr "${file}" "${param}")|${set}|g"
}

function read_tag() {
    file=$1
    tag=$2
    sed -n "s|\(.*\)<${tag}>\(.*\)</${tag}>|\2|p" "${file}"
}

function check_scripts() {
    if [[ ! -f $HOME/scripts/hosted-scripts ]]; then
        mkdir -p "$HOME/scripts"
        git clone "https://github.com/brettpetch/hosted-scripts.git" "$HOME/scripts/hosted-scripts"
    fi
}

function github_latest_version() {
    # Liara (2022)
    # Argument expects the author/repo format
    # e.g. swizzin/swizzin
    repo=$1
    curl -fsSLI -o /dev/null -w %{url_effective} "https://github.com/${repo}/releases/latest" | grep -o '[^/]*$'
}


function install_stop() {
    sudo box install "$1"
    echo "Waiting 10 seconds in hopes of this not breaking things"
    sleep 10
    sudo box stop "$1"
}

function migrateData() {
    echo "Please make sure you're running this script inside a screen window... It will cause data loss if this is not done properly."
    echo "If you wish to stop, press ctl-c within the next 5 seconds..."
    sleep 5

    echo "Welcome to the HostingBy Migration Script"
    echo "This script will inventory your current slot and copy the data for you."
    echo "While we do provide partial support, we are not responsible should the slot explode in some unpredictable way."

    echo "Please enter your new hostname:"
    read -r newhost
    export newhost

    echo "Please enter your new username:"
    read -r newuser
    export newuser

    echo "Writing essential information to $HOME/.info.lock, $HOME/systemd.list, and $HOME/crontab.bak"
    if [[ -z $(crontab -l) ]]; then
        CT=FALSE
    else
        CT=TRUE
    fi
    cat > "$HOME/.info.lock" << EOF
[general]
HOME = $HOME
USER = $USER
UID = $(id -u "$USER")
GID = $(id -g "$USER")
GROUPS = $(id -G "$USER")
SUBNET = $(cat "$HOME/.install/subnet.lock")
CRONTAB = "${CT}"
EOF
    systemctl list-units --type=service --user > "$HOME/systemd.list"
    crontab -l 1> "$HOME/crontab.bak" 2> /dev/null
    for i in $HOME/.install/.*.lock; do
        i=$(echo "$i" | cut -d/ -f5 | cut -d. -f2)
        echo "Attempting to stop $i"
        sudo box stop "${i}" || systemctl --user -q stop "${i}" || sudo systemctl stop -q "${i}@$(whoami)"
        echo "${i}" >> applist.txt
    done
    echo "Copying data from $HOME to ${newhost}:\$HOME/old... This could take some time."
    rsync -ahH --info=progress2 "$HOME/" "${newuser}@${newhost}:old/" -e 'ssh -p22'
}

function runner() {
    if [[ ! -f $HOME/old/.info.lock ]];
        echo "Old user info couldn’t be retrieved. Please ensure \$HOME/.info.lock was transferred into $HOME/old/.info.lock"
        exit 1
    fi
    export eula="yes"
    migrateAutoDL
    migrateBazarr
    migrateBTSync
    migrateDeluge
    migrateEmby
    migrateJackett
    migrateJellyfin
    migrateLidarr
    migrateMedusa
    migrateNZBGet
    migrateOmbi
    migratePlex
    migratePlexTunnel
    migrateQbit
    migrateRadarr
    migrateRtorrent
    migrateSabnzbd
    migrateSonarr
    migrateTautulli
    migrateFilebrowser
    migrateKativa
    migrateKomga
    migrateLounge
    migrateMylar
    migrateNGPost
    migrateOverseerr
    migrateProwlarr
    migrateRadarr4K
    migrateReadarr
    migrateSonarr4k
    migrateSubsonic
    migrateUnpackerr
}

function migrateAutoDL() {
    if [[ ! -f $HOME/old/.install/.autodl.lock ]]; then
        echo "Autodl was not previously installed... Skipping!"
        return
    fi
    install_stop autodl
    port=$(grep "gui-server-port" "$HOME/.autodl/autodl.cfg" | cut -d= -f2 | xargs)
    pass=$(grep "gui-server-password" "$HOME/.autodl/autodl.cfg" | cut -d= -f2 | xargs)
    sed -i "s/gui-server-port = */gui-server-port = ${port}/g" "$HOME/old/.autodl/autodl.cfg"
    sed -i "s/gui-server-password = */gui-server-port = ${pass}/g" "$HOME/old/.autodl/autodl.cfg"
    sudo box start autodl
}

function migrateBazarr() {
    if [[ ! -f $HOME/old/.install/.bazarr.lock ]]; then
        echo "Bazarr was not previously installed... Skipping!"
        return
    fi
    install_stop bazarr
    set_ini "$HOME/old/Apps/bazarr/data/config/config.ini" "general" "ip" $(cat $HOME/.install/subnet.lock)
    set_ini "$HOME/old/Apps/bazarr/data/config/config.ini" "general" "port" "$(get_ini \"$HOME/Apps/bazarr/data/config/config.ini\" \"general\" \"port\")"
    mv "$HOME/Apps/bazarr/data" "$HOME/Apps/bazarr/data.bak"
    mv "$HOME/old/Apps/bazarr/data" "$HOME/Apps/bazarr/data"
}

function migrateBTSync() {
    if [[ ! -f $HOME/old/.install/.btsync.lock ]]; then
        echo "btsync was not previously installed... Skipping!"
        return
    fi
    sudo box install btsync
}

function migrateDeluge() {
    if [[ ! -f $HOME/old/.install/.deluge.lock ]]; then
        echo "deluge was not previously installed... Skipping!"
        return
    fi
    echo "Deluge fastresume data is not easy to edit. We will move all torrents currently in Deluge over to qBittorrent."
    echo "You have 5 seconds to cancel this action by pressing ctl-c."
    sleep 5
    install_stop qbittorrent
    echo "Installing ludviglundgren/qbittorrent-cli to edit fastresume data. This will be accessible after as \`qbt\`"
    version=$(github_latest_version ludviglundgren/qbittorrent-cli)
    curl -sL "https://github.com/ludviglundgren/qbittorrent-cli/releases/download/${version}/qbittorrent-cli_${version//v}_linux_amd64.tar.gz" -o "$HOME/.tmp/qbittorrent-cli.tar.gz"
    cd "$HOME/.tmp/" || { 
        echo "Failed to migrate qbittorrent" && exit 1 
    }
    tar xvf "$HOME/.tmp/qbittorrent-cli.tar.gz"
    rm -f qbtcli.tar.gz README.md
    chmod +x "$HOME/.tmp/qbt"
    mkdir -p "$HOME/.local/bin"
    mv "$HOME/.tmp/qbt" "$HOME/.local/bin/qbt"
    oldhome=$(get_ini "$HOME/old/.info.lock" "general" "HOME")
    sudo box stop qbittorrent
    # Import Deluge torrents to qBit
    # Change dir.
    "$HOME/.local/bin/qbt" import --source deluge --source-dir "$HOME/old/.config/deluge/state/" --qbit-dir "$HOME/.local/share/data/qBittorrent/BT_backup"
    "$HOME/.local/bin/qbt" edit --dir "$HOME/.local/share/qBittorrent/BT_backup" --pattern "$oldhome" --replace "$HOME"
    echo "Data from Deluge has been migrated to qBittorrent."
    echo "Starting qBittorrent."
    sudo box start qbittorrent
}

function migrateEmby() {
    if [[ ! -f $HOME/old/.install/.emby.lock ]]; then
        echo "Emby was not previously installed... Skipping!"
        return
    fi
    install_stop emby
    # Old ports
    jellyfin_old_port=$(sed -n 's|\(.*\)<PublicPort>\(.*\)</PublicPort>|\2|p' "$HOME/old/.emby/config/config/network.xml")
    jellyfin_old_baseurl=$(sed -n 's|\(.*\)<BaseUrl>\(.*\)</BaseUrl>|\2|p' "$HOME/old/.emby/config/config/network.xml")
    jellyfin_old_kp=$(sed -n 's|\(.*\)<KnownProxies>\(.*\)</KnownProxies>|\2|p' "$HOME/old/.emby/config/config/network.xml")
    # Get new ports
    jellyfin_port=$(sed -n 's|\(.*\)<PublicPort>\(.*\)</PublicPort>|\2|p' "$HOME/.emby/config/config/network.xml")
    jellyfin_baseurl=$(sed -n 's|\(.*\)<BaseUrl>\(.*\)</BaseUrl>|\2|p' "$HOME/.emby/config/config/network.xml")
    jellyfin_kp=$(sed -n 's|\(.*\)<KnownProxies>\(.*\)</KnownProxies>|\2|p' "$HOME/.emby/config/config/network.xml")
    # good ol sed to select the old vals and replace
    sed -i "s|${jellyfin_old_port}|${jellyfin_port}|g" "$HOME/old/.emby/config/config/network.xml"
    sed -i "s|${jellyfin_old_baseurl}|${jellyfin_baseurl}|g" "$HOME/old/.emby/config/config/network.xml"
    sed -i "s|${jellyfin_old_kp}|${jellyfin_kp}|g" "$HOME/old/.emby/config/config/network.xml"
    # Move the new into a backup, move old into normal install location
    mv "$HOME/.emby" "$HOME/.emby.bak"
    mv "$HOME/old/.emby" "$HOME/.emby"
    sudo box start emby
}

function migrateJackett() {
    if [[ ! -f $HOME/old/.install/.jackett.lock ]]; then
        echo "btsync was not previously installed... Skipping!"
        return
    fi
    install_stop jackett
    cp "$HOME/.config/Jackett/ServerConfig.json" "$HOME/.config/Jackett/ServerConfig.json.bak"
    port=$(jq ".Port" "$HOME/.config/Jackett/ServerConfig.json.bak")
    admin_pass=$(jq ".AdminPassword" "$HOME/.config/Jackett/ServerConfig.json.bak")
    cp -r "$HOME/old/.config/Jackett/" "$HOME/.config/Jackett/"
    tmp=$(mktemp)
    jq ".Port=${port}" "$HOME/.config/Jackett/ServerConfig.json" > "$tmp" && mv "$tmp" "$HOME/.config/Jackett/ServerConfig.json"
    jq ".AdminPassword=${admin_pass}" "$HOME/.config/Jackett/ServerConfig.json.bak" > "$tmp" && mv "$tmp" "$HOME/.config/Jackett/ServerConfig.json"
}

function migrateJellyfin() {
    if [[ ! -f $HOME/old/.install/.jackett.lock ]]; then
        echo "Jackett was not previously installed... Skipping!"
        return
    fi
    install_stop jellyfin
    install_stop emby
    # Old ports
    jellyfin_old_port=$(sed -n 's|\(.*\)<PublicPort>\(.*\)</PublicPort>|\2|p' "$HOME/old/.jellyfin/config/config/network.xml")
    jellyfin_old_baseurl=$(sed -n 's|\(.*\)<BaseUrl>\(.*\)</BaseUrl>|\2|p' "$HOME/old/.jellyfin/config/config/network.xml")
    jellyfin_old_kp=$(sed -n 's|\(.*\)<KnownProxies>\(.*\)</KnownProxies>|\2|p' "$HOME/old/.jellyfin/config/config/network.xml")
    # Get new ports
    jellyfin_port=$(sed -n 's|\(.*\)<PublicPort>\(.*\)</PublicPort>|\2|p' "$HOME/.jellyfin/config/config/network.xml")
    jellyfin_baseurl=$(sed -n 's|\(.*\)<BaseUrl>\(.*\)</BaseUrl>|\2|p' "$HOME/.jellyfin/config/config/network.xml")
    jellyfin_kp=$(sed -n 's|\(.*\)<KnownProxies>\(.*\)</KnownProxies>|\2|p' "$HOME/.jellyfin/config/config/network.xml")
    # good ol sed to select the old vals and replace
    sed -i "s|${jellyfin_old_port}|${jellyfin_port}|g" "$HOME/old/.jellyfin/config/config/network.xml"
    sed -i "s|${jellyfin_old_baseurl}|${jellyfin_baseurl}|g" "$HOME/old/.jellyfin/config/config/network.xml"
    sed -i "s|${jellyfin_old_kp}|${jellyfin_kp}|g" "$HOME/old/.jellyfin/config/config/network.xml"
    # Move the new into a backup, move old into normal install location
    mv "$HOME/.jellyfin" "$HOME/.jellyfin.bak"
    mv "$HOME/old/.jellyfin" "$HOME/.jellyfin"
    sudo box start jellyfin
}

function migrateLidarr() {
    if [[ ! -f $HOME/old/.install/.lidarr.lock ]]; then
        echo "Lidarr was not previously installed... Skipping!"
        return
    fi
    install_stop lidarr
    lidarr_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' "$HOME/.config/Lidarr/config.xml")
    old_lidarr_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' "$HOME/old/.config/Lidarr/config.xml")
    old_subnet=$(get_ini $HOME/old/.info.lock general SUBNET)
    subnet=$(cat $HOME/.install/subnet.lock)
    sed -i "s|${old_subnet}|${subnet}|g" "$HOME/old/.config/Lidarr/config.xml"
    sed -i "s|${old_lidarr_port}|${lidarr_port}|g" "$HOME/old/.config/Lidarr/config.xml"
    mv "$HOME/.config/Lidarr" "$HOME/.config/Lidarr.bak" 
    mv "$HOME/old/.config/Lidarr/" "$HOME/.config/Lidarr/"
    sudo box start lidarr
}

function migrateMedusa() {
    if [[ ! -f $HOME/old/.install/.medusa.lock ]]; then
        echo "Medusa was not previously installed... Skipping!"
        return
    fi
    install_stop medusa
}

function migrateNZBGet() {
    if [[ ! -f $HOME/old/.install/.nzbget.lock ]]; then
        echo "NZBGet was not previously installed... Skipping!"
        return
    fi
    install_stop nzbget
    subnet=$(cat $HOME/.install/subnet.lock)
    nzb_port=$(awk -F "=" '/ControlPort/ {print $2}' "$HOME/nzbget/nzbget.conf")
    sed -i "s|ControlIP=.*|ControlIP=${subnet}|g"  "$HOME/old/nzbget/nzbget.conf"
    sed -i "s|ControlPort=.*|ControlPort=${nzb_port}|g"  "$HOME/old/nzbget/nzbget.conf"
    cp "$HOME/old/nzbget/nzbget.conf" "$HOME/nzbget/nzbget.conf"
    sudo box start nzbget
}

function migrateOmbi() {
    if [[ ! -f $HOME/old/.install/.ombi.lock ]]; then
        echo "Ombi was not previously installed... Skipping!"
        return
    fi
    install_stop ombi
}

function migratePlex() {
    if [[ ! -f $HOME/old/.install/.plex.lock ]]; then
        echo "Plex was not previously installed... Skipping!"
        return
    fi
    install_stop plex
    echo "You MUST make sure your old Plex install is STOPPED. If it is not, this will NOT pick up easily. You will need to change library locations when this is completed."
    # Record All Ports & Custom Access stuff
    cp "$HOME/.plex/config/Library/Application Support/Plex Media Server/Preferences.xml" "$HOME/.plex/config/Library/Application Support/Plex Media Server/Preferences.xml.bak"
    plex_port=$(grep -Pio 'ManualPortMappingPort=*"\K[^"]*' "$HOME/.plex/config/Library/Application Support/Plex Media Server/Preferences.xml.bak")
    old_plex_port=$(grep -Pio 'ManualPortMappingPort=*"\K[^"]*' "$HOME/old/.plex/config/Library/Application Support/Plex Media Server/Preferences.xml")
    plex_custom_connections=$(grep -Pio 'customConnections=*"\K[^"]*' "$HOME/.plex/config/Library/Application Support/Plex Media Server/Preferences.xml.bak")
    old_plex_custom_connections=$(grep -Pio 'customConnections=*"\K[^"]*' "$HOME/old/.plex/config/Library/Application Support/Plex Media Server/Preferences.xml")
    sed -i "s|${old_plex_custom_connections}|${plex_custom_connections}|g" "$HOME/old/.plex/config/Library/Application Support/Plex Media Server/Preferences.xml"
    sed -i "s|${old_plex_port}|${plex_port}|g" "$HOME/old/.plex/config/Library/Application Support/Plex Media Server/Preferences.xml"
    cp -r "$HOME/old/.plex/config/Library/Application Support/Plex Media Server/" "$HOME/.plex/config/Library/Application Support/Plex Media Server/"
    sudo box start plex
}

function migratePlexTunnel() {
    if [[ ! -f $HOME/old/.install/.plex-tunnel.lock ]]; then
        echo "Plex Tunnel was not previously installed... Skipping!"
        return
    fi
    install_stop plex-tunnel
}

function migrateQbit() {
    if [[ ! -f $HOME/old/.install/.qbittorrent.lock ]]; then
        echo "qBittorrent was not previously installed... Skipping!"
        return
    fi
    install_stop qbittorrent
    mkdir -p "$HOME/.tmp/"
    echo "Installing ludviglundgren/qbittorrent-cli to edit fastresume data. This will be accessible after as \`qbt\`"
    version=$(github_latest_version ludviglundgren/qbittorrent-cli)
    curl -sL "https://github.com/ludviglundgren/qbittorrent-cli/releases/download/${version}/qbittorrent-cli_${version//v}_linux_amd64.tar.gz" -o "$HOME/.tmp/qbittorrent-cli.tar.gz"
    cd "$HOME/.tmp/" || { 
        echo "Failed to migrate qbittorrent" && exit 1 
    }
    tar xvf "$HOME/.tmp/qbittorrent-cli.tar.gz"
    rm -f qbtcli.tar.gz README.md
    chmod +x "$HOME/.tmp/qbt"
    mkdir -p "$HOME/.local/bin"
    mv "$HOME/.tmp/qbt" "$HOME/.local/bin/qbt"
    oldhome=$(get_ini "$HOME/old/.info.lock" "general" "HOME")
    "$HOME/.local/bin/qbt" edit --dir "$HOME/old/.local/share/qBittorrent/BT_backup" --pattern "${oldhome}" --replace "$HOME"
    cp -r "$HOME/old/.local/share/qBittorrent/BT_backup" "$HOME/.local/share/qBittorrent/BT_backup/"
    # Set config to pickup where we left off
    webui_port=$(get_ini "$HOME/.config/qBittorrent/qBittorrent.conf" "Preferences" "WebUI\\\Port")
    connection_port_min=$(get_ini "$HOME/.config/qBittorrent/qBittorrent.conf" "Preferences" "Connection\\\PortRangeMin")
    session_port=$(get_ini "$HOME/.config/qBittorrent/qBittorrent.conf" "BitTorrent" "Session\\\Port")
    qbit_encodedpass=$(get_ini "$HOME/.config/qBittorrent/qBittorrent.conf" "Preferences" "WebUI\\\Password_PBKDF2")
    set_ini "$HOME/old/.config/qBittorrent/qBittorrent.conf" "Preferences" "WebUI\\\Port" "${webui_port}"
    set_ini "$HOME/old/.config/qBittorrent/qBittorrent.conf" "Preferences" "WebUI\\\AlternativeUIEnabled" "false"
    set_ini "$HOME/old/.config/qBittorrent/qBittorrent.conf" "Preferences" "Connection\\\PortRangeMin" "${connection_port_min}"
    set_ini "$HOME/old/.config/qBittorrent/qBittorrent.conf" "BitTorrent" "Session\\\Port" "${session_port}"
    set_ini "$HOME/old/.config/qBittorrent/qBittorrent.conf" "Preferences" "WebUI\\\Password_PBKDF2" "${qbit_encodedpass}"
    cp "$HOME/old/.config/qBittorrent/qBittorrent.conf" "$HOME/.config/qBittorrent/qBittorrent.conf"
    box start qbittorrent
}

function migrateRadarr() {
    if [[ ! -f $HOME/old/.install/.radarr.lock ]]; then
        echo "Radarr was not previously installed... Skipping!"
        return
    fi
    install_stop radarr
    # keep old api, no need to use new one.
    subnet=$(cat "$HOME/.config/subnet.lock")
    radarr_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' "$HOME/.config/Radarr/config.xml")
    old_radarr_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' "$HOME/old/.config/Radarr/config.xml")
    old_subnet=$(get_ini $HOME/old/.info.lock general SUBNET)
    subnet=$(cat $HOME/.install/subnet.lock)
    sed -i "s|${old_subnet}|${subnet}|g" "$HOME/old/.config/Radarr/config.xml"
    sed -i "s|${old_radarr_port}|${radarr_port}|g" "$HOME/old/.config/Radarr/config.xml"
    mv "$HOME/.config/Radarr" "$HOME/.config/Radarr.bak" 
    mv "$HOME/old/.config/Radarr/" "$HOME/.config/Radarr/"
    sudo box start radarr
}

function migrateRtorrent() {
    if [[ ! -f $HOME/old/.install/.rtorrent.lock ]]; then
        echo "rtorrent was not previously installed... Skipping!"
        return
    fi
    install_stop rtorrent
    mv $HOME/.sessions $HOME/.sessions.bak
    cp -r "$HOME/old/.sessions/" "$HOME/.sessions"
    sed -i "s|${old_home}/|${HOME}/|g" "$HOME/.sessions/*"
    sudo box start rtorrent
}

function migrateSabnzbd() {
    if [[ ! -f $HOME/old/.install/.sabnzbd.lock ]]; then
        echo "SABNzbd was not previously installed... Skipping!"
        return
    fi
    install_stop sabnzbd
}

function migrateSonarr() {
    if [[ ! -f $HOME/old/.install/.sonarr.lock ]]; then
        echo "Sonarr was not previously installed... Skipping!"
        return
    fi
    install_stop sonarr
    # keep old api, no need to use new one.
    subnet=$(cat "$HOME/.config/subnet.lock")
    sonarr_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' "$HOME/.config/Sonarr/config.xml")
    old_sonarr_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' "$HOME/old/.config/Sonarr/config.xml")
    old_subnet=$(get_ini $HOME/old/.info.lock general SUBNET)
    subnet=$(cat $HOME/.install/subnet.lock)
    sed -i "s|${old_subnet}|${subnet}|g" "$HOME/old/.config/Sonarr/config.xml"
    sed -i "s|${old_sonarr_port}|${sonarr_port}|g" "$HOME/old/.config/Sonarr/config.xml"
    mv "$HOME/.config/Sonarr" "$HOME/.config/Sonarr.bak" 
    mv "$HOME/old/.config/Sonarr/" "$HOME/.config/Sonarr/"
    sudo box start sonarr
}

function migrateTautulli {
    if [[ ! -f $HOME/old/.install/.plexpy.lock ]]; then
        echo "Tautulli was not previously installed... Skipping!"
        return
    fi
    install_stop plexpy
    # edit ini
    taut_port=$(get_ini $HOME/plexpy/config.ini General http_port)
    old_home=$(get_ini "$HOME/old/.info.lock" "general" "HOME")
    subnet=$(cat $HOME/.install/subnet.lock)
    set_ini "$HOME/old/plexpy/config.ini" General http_host $subnet
    set_ini "$HOME/plexpy/config.ini" General http_port $taut_port
    sed -i "s|$old_home/|$HOME/|g" "$HOME/old/plexpy/config.ini"
    mv "$HOME/old/plexpy/" "$HOME/plexpy/"
    sudo box start plexpy
}

function migrateFilebrowser() {
    if [[ ! -f $HOME/old/.install/.filebrowser.lock ]]; then
        echo "Filebrowser was not previously installed... Skipping!"
        return
    fi
    check_scripts
    bash "$HOME/scripts/hosted-scripts/filebrowser.sh"
}

function migrateKativa() {
    if [[ ! -f $HOME/old/.install/.kativa.lock ]]; then
        echo "Kativa was not previously installed... Skipping!"
        return
    fi
    check_scripts
    bash "$HOME/scripts/hosted-scripts/kativa.sh"
}

function migrateKomga() {
    if [[ ! -f $HOME/old/.install/.komga.lock ]]; then
        echo "Komga was not previously installed... Skipping!"
        return
    fi
    check_scripts
    bash "$HOME/scripts/hosted-scripts/komga.sh"

}

function migrateLounge() {
    if [[ ! -f $HOME/old/.install/.lounge.lock ]]; then
        echo "Lounge was not previously installed... Skipping!"
        return
    fi
    check_scripts
    bash "$HOME/scripts/hosted-scripts/lounge.sh"
}

function migrateMylar() {
    if [[ ! -f $HOME/old/.install/.mylar.lock ]]; then
        echo "Mylar was not previously installed... Skipping!"
        return
    fi
    check_scripts
    bash "$HOME/scripts/hosted-scripts/mylar.sh"
}

function migrateNGPost() {
    if [[ ! -f $HOME/old/.install/.ngpost.lock ]]; then
        echo "NGPost was not previously installed... Skipping!"
        return
    fi
    check_scripts
    bash "$HOME/scripts/hosted-scripts/ngpost.sh"

}

function migrateOverseerr() {
    if [[ ! -f $HOME/old/.install/.overseerr.lock ]]; then
        echo "Overseerr was not previously installed... Skipping!"
        return
    fi
    check_scripts
    bash "$HOME/scripts/hosted-scripts/overseerr.sh"
}

function migrateProwlarr() {
    if [[ ! -f $HOME/old/.install/.prowlarr.lock ]]; then
        echo "Prowlarr was not previously installed... Skipping!"
        return
    fi
    check_scripts
    bash "$HOME/scripts/hosted-scripts/prowlarr.sh"
    prowlarr_port=$(new_port 9696 12000)
    old_prowlarr_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' "$HOME/old/.config/Prowlarr/config.xml")
    sed -i "s|${old_prowlarr_port}|${prowlarr_port}|g" "$HOME/old/.config/Prowlarr/config.xml"
    mv "$HOME/.config/Prowlarr" "$HOME/.config/Prowlarr.bak" 
    mv "$HOME/old/.config/Prowlarr/" "$HOME/.config/Prowlarr/"

}

function migrateRadarr4K() {
    if [[ ! -f $HOME/old/.install/.radarr4k.lock ]]; then
        echo "Radarr4k was not previously installed... Skipping!"
        return
    fi
    check_scripts
    bash "$HOME/scripts/hosted-scripts/radarr4k.sh"
    echo "Please secure your instance!"
}

function migrateReadarr() {
    if [[ ! -f $HOME/old/.install/.readarr.lock ]]; then
        echo "Readarr was not previously installed... Skipping!"
        return
    fi
    check_scripts
    bash "$HOME/scripts/hosted-scripts/readarr.sh"
    readarr_port=$(new_port 9696 12000)
    old_readarr_port=$(sed -n 's|\(.*\)<Port>\(.*\)</Port>|\2|p' "$HOME/old/.config/Readarr/config.xml")
    sed -i "s|${old_readarr_port}|${readarr_port}|g" "$HOME/old/.config/Readarr/config.xml"
    mv "$HOME/.config/Readarr" "$HOME/.config/Readarr.bak" 
    mv "$HOME/old/.config/Readarr/" "$HOME/.config/Readarr/"
    echo "Please secure your instance!"
}

function migrateSonarr4k() {
    if [[ ! -f $HOME/old/.install/.sonarr4k.lock ]]; then
        echo "Sonarr4k was not previously installed... Skipping!"
        return
    fi
    check_scripts
    bash "$HOME/scripts/hosted-scripts/sonarr4k.sh"
    echo "Please secure your instance!"
}

function migrateSubsonic() {
    if [[ ! -f $HOME/old/.install/.subsonic.lock ]]; then
        echo "Subsonic was not previously installed... Skipping!"
        return
    fi
    # idk how this one works
    check_scripts
    bash "$HOME/scripts/hosted-scripts/subsonic.sh"
}

function migrateUnpackerr() {
    if [[ ! -f $HOME/old/.install/.unpackerr.lock ]]; then
        echo "Unpackerr was not previously installed... Skipping!"
        return
    fi
    # More than this is extra... will not happen.
    check_scripts
    bash "$HOME/scripts/hosted-scripts/unpackerr.sh"
}

echo "Welcome to the HostingBy Migration Script"
echo "This script will inventory your current slot and copy the data for you."
echo "While we do provide partial support, we are not responsible should the slot explode in some unpredictable way."
echo "What do you like to do?"
echo ""
echo "move = Run me on your old slot!"
echo "migrate = Run me on your new slot!"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "move")
            migrateData
            break
            ;;
        "migrate")
            runner
            break
            ;;
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
