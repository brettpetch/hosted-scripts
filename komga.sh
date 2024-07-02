#!/bin/bash
# Thanks to Snd from Komga Discord for telling us about how to re-bind tmpdir.
user=$(whoami)
mkdir -p "$HOME/.logs/"
export log="$HOME/.logs/komga.log"
touch "$log"

function java_install() {
    type java || {
        echo "Java not installed..."
        # Java 8
        echo "Downloading java"
        curl -sL "https://download.oracle.com/java/17/archive/jdk-17.0.10_linux-x64_bin.tar.gz" -o /tmp/jre.tar.gz >> "$log" 2>&1
        echo "Extracting java"
        tar -xvf /tmp/jre.tar.gz --strip-components=1 -C "/home/${user}/.local/" >> "$log" 2>&1
        rm /tmp/jre.tar.gz
        . "/home/${user}/.profile"
    }
}

function port() {
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq ${LOW_BOUND} ${UPPER_BOUND} | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function github_latest_version() {
    # Argument expects the author/repo format
    # e.g. swizzin/swizzin
    repo=$1
    curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/${repo}/releases/latest | grep -o '[^/]*$'
}

function _install() {
    echo "Beginning installation..."
    mkdir -p "$HOME/komga"
    mkdir -p "$HOME/.tmp"
    java_install
    echo "Downloading Komga"
    version=$(github_latest_version gotson/komga)
    dlurl="https://github.com/gotson/komga/releases/download/$version/komga-${version//v}.jar"
    wget "$dlurl" -O "$HOME/komga/komga.jar" >> "${log}" 2>&1 || {
        echo "Download failed"
        exit 1
    }
    mkdir "$HOME/.config/systemd/user"
    echo "Figuring out a port to host komga on..."
    port=$(port 5900 9900)
    echo "Writing Service File"
    cat > "$HOME/.config/systemd/user/komga.service" <<- SERV
[Unit]
Description=Komga server
[Service]
WorkingDirectory=$HOME/komga/
ExecStart=$HOME/.local/bin/java -jar -Xmx1g -Djava.io.tmpdir=$HOME/.tmp $HOME/komga/komga.jar --server.servlet.context-path="/komga" --server.port="${port}"
Type=simple
Restart=on-failure
RestartSec=10
StandardOutput=null
StandardError=syslog
[Install]
WantedBy=default.target
SERV

    echo "Starting service..."
    systemctl enable --user --now komga -q
    echo "Service stared."
    touch "$HOME/.install/.komga.lock"
    echo "Komga has been installed and should be running at http://$(hostname -f):${port}/komga/"
}

function _upgrade() {
    if [ ! -f /install/.komga.install ]; then
        echo "You ain't got no komga, whacha doen"
        exit 1
    fi
    echo "Downloading komga"
    version=$(github_latest_version gotson/komga)
    dlurl="https://github.com/gotson/komga/releases/download/$version/komga-${version//v}.jar"
    wget "$dlurl" -O "$HOME/komga/komga.jar" >> "${log}" 2>&1 || {
        echo_error "Download failed"
        exit 1
    }
    systemctl try-restart --user komga
}

function _remove() {
    systemctl stop --user komga
    systemctl disable --user komga
    rm -rf "$HOME/komga/"
    rm -f "$HOME/.config/systemd/user/komga.service"
    rm -f "$HOME/.install/.komga.lock"
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

echo "Welcome to the Komga installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "install = Install Komga"
echo "upgrade = upgrades Komga to latest version"
echo "uninstall = Completely removes Komga"
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
