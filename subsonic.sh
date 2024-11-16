#!/bin/bash
# Subsonic Installer
# By B for Swizzin Hosted (2022)
user=$(whoami)
mkdir -p "/home/${user}/.logs/"
export log="/home/${user}/.logs/subsonic.log"
touch "$log"

function java_install() {
    type java || {
        echo "Java not installed..."
        # Java 8
        echo "Downloading java"
        curl -sL "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=246255_165374ff4ea84ef0bbd821706e29b123" -o /tmp/jre.tar.gz >> "$log" 2>&1
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

function _install() {
    java_install
    echo "Downloading subsonic"
    mkdir -p "$HOME/.config/subsonic"
    mkdir -p "$HOME/subsonic"
    mkdir -p "$HOME/subsonic/transcode/"
    ln -s "$(which ffmpeg)" "$HOME/subsonic/transcode/"
    curl -sL "https://s3-eu-west-1.amazonaws.com/subsonic-public/download/subsonic-6.1.6-standalone.tar.gz" -o "$HOME/subsonic/subsonic.tar.gz" >> "$log" 2>&1

    echo "Extracting Subsonic"
    tar -xvf "$HOME/subsonic" -C "$HOME/subsonic/subsonic.tar.gz" >> "$log" 2>&1
    port=$(port 4096 12000)
    
    echo "Setting up service file"
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/subsonic.service" << EOF
[Unit]
Description=Subsonic Media Server
After=remote-fs.target network.target
AssertPathExists=$HOME/subsonic

[Service]
Type=simple
WorkingDirectory=$HOME/subsonic/
ExecStart=$HOME/.local/bin/java -Xmx700m \\
    -Dsubsonic.home=$HOME/subsonic \\
    -Dsubsonic.host=0.0.0.0 \\
    -Dsubsonic.port=${port} \\
    -Dsubsonic.contextPath=/subsonic \\
    -Djava.awt.headless=true \\
    -verbose:gc \\
    -jar subsonic-booter-jar-with-dependencies.jar

[Install]
WantedBy=default.target
EOF

    echo "Starting the subsonic service"
    systemctl -q --user enable --now subsonic
    echo "Subsonic will run on http://$(hostname -f):${port}/subsonic"
    echo "The default login is admin/admin. Please change this!"
    echo "Please be sure to disable the uPNP service!"
}

function subsonic_remove() {
    systemctl --user stop subsonic >> "$log" 2>&1
    systemctl --user disable subsonic >> "$log" 2>&1
    rm -r "$HOME/subsonic"
    rm "$HOME/.config/systemd/user/subsonic.service"
    rm -r "$HOME/.config/subsonic"
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

echo "Welcome to the Subsonic installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "install = Install Subsonic"
echo "upgrade = upgrades Subsonic to latest version"
echo "uninstall = Completely removes Subsonic"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            _install
            break
            ;;
        "uninstall")
            subsonic_remove
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
