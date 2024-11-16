#!/bin/bash
##
# Brett Petch 2022
# GPL v3
# Some functions refactored from Swizzin Project
# https://swizzin.ltd
##

export user=$(whoami)
mkdir -p "$HOME/.logs/"
export log="$HOME/.logs/mylar.log"
touch "$log"

function pyenv_install(){
    mkdir -p $HOME/.local/opt
    # Clone pyenv
    git clone https://github.com/pyenv/pyenv.git $HOME/.local/opt/pyenv
    git clone https://github.com/pyenv/pyenv-virtualenv.git $HOME/.local/opt/pyenv/plugins/pyenv-virtualenv
    git clone https://github.com/pyenv/pyenv-update.git $HOME/.local/opt/pyenv/plugins/pyenv-update
    echo 'export PYENV_ROOT="$HOME/.local/opt/pyenv"' >> $HOME/.bashrc
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> $HOME/.bashrc
    export PYENV_ROOT="$HOME/.local/opt/pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
}

function pyenv_update(){
    $HOME/.local/opt/pyenv/bin/pyenv update
}

# Install a specific version of python through `pyenv` if not yet available
# \
# Parameters:
# - `$1` = The version necessary
function pyenv_install_version() {
    version=$1
    versions=$($HOME/.local/opt/pyenv/bin/pyenv versions 2>> "$log")
    if [[ ! $versions =~ $version ]]; then
        echo "Compiling Python $version. This may take some time"
        export TMPDIR="$HOME/.tmp"
        mkdir -p "$TMPDIR"
        $HOME/.local/opt/pyenv/bin/pyenv install "$version" >> "$log" 2>&1
        echo "Python $version compiled"
    else
        echo "Python $version already installed!"
    fi
}

# Install venv of a specific version
# \
# Parameters:
# - `$1` = The version necessary
# - `$2` = Full path of the destination to create it in
function pyenv_create_venv() {
    version=$1
    destination=$2
    echo "Creating venv ($version) in $destination"
    mkdir -p $destination
    $HOME/.local/opt/pyenv/versions/"$version"/bin/python3 -m venv "$destination" >> "$log" 2>&1
    echo "venv created"
}

# Finds a random free port between a range
# \
# Parameters:
# $1 = Lower bound
# $2 = Upper bound
# \
# Returns an integer
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

http_port=$(port 3000 9000)

function _download() {
    echo "Downloading Mylarr"
    mylar_latest=$(github_latest_version mylar3/mylar3)
    curl -sL https://github.com/mylar3/mylar3/archive/refs/tags/${mylar_latest}.tar.gz -o /tmp/mylar.tar.gz >> "$log" 2>&1 || {
        echo "Failed to download Mylar from GitHub"
        exit 1
    }
    echo "Downloaded Mylar"

    echo "Extracting Mylar"
    mkdir -p "$HOME/mylar"
    tar xvf /tmp/mylar.tar.gz --directory "$HOME/mylar" --strip-components=1 >> "$log" 2>&1 || {
        echo "Failed to download Mylar from GitHub"
        exit 1
    }

    rm -f /tmp/mylar.tar.gz

    echo "Installing Python Dependencies"
    $HOME/.venv/mylar/bin/pip install --upgrade pip &>> "${log}"
    $HOME/.venv/mylar/bin/pip install -r $HOME/mylar/requirements.txt &>> "${log}"
    echo "Intalled Python Dependencies"
}

function _install() {
    echo "Starting Mylar3 Install"
    # Not using system python because mylar likes to bump deps with no warning
    if [[ ! -d "$HOME/.local/opt/pyenv" ]]; then
        echo "Installing pyenv..."
        pyenv_install
    fi
    # Using most heavily tested for stability
    # https://github.com/mylar3/mylar3/wiki/Installation-Instructions
    pyenv_install_version 3.9.4
    pyenv_create_venv 3.9.4 "$HOME/.venv/mylar"

    # Download Latest
    _download
    echo "Installing systemd service"
    mkdir -p "$HOME/.config/systemd/user/"
    cat > "$HOME/.config/systemd/user/mylar.service" << EOS
[Unit]
Description=Mylar service
After=network-online.target

[Service]
Type=forking
ExecStart=$HOME/.venv/mylar/bin/python3 $HOME/mylar/Mylar.py --datadir $HOME/.config/mylar/ -v --daemon  --nolaunch --quiet
WorkingDirectory=$HOME/mylar/
GuessMainPID=no
Restart=on-failure

[Install]
WantedBy=default.target
EOS

    echo "Please enter a password for Mylar user ${user} to use."
    read -rep "" pass

    mkdir -p "$HOME/.config/mylar/"
    cat > "$HOME/.config/mylar/config.ini" << EOF
[Interface]
http_port = ${http_port}
http_host = 0.0.0.0
http_root = /
authentication = 1
http_username = ${user}
http_password = ${pass}
EOF

    echo "Starting Systemd Service"
    systemctl --user -q daemon-reload
    systemctl --user enable -q --now mylar
    echo "Mylar is now installed."
    echo "You can find it running at http://$(hostname -f):${http_port}/ -- Enjoy!"
}

function _remove(){
    systemctl --user stop -q --now mylar
    systemctl --user disable -q --now mylar
    rm -rf "$HOME/.config/mylar"
    rm -f "$HOME/.config/systemd/user/mylar.service"
    rm -rf "$HOME/.venv/mylar"
    rm -rf "$HOME/mylar"
    echo "Python 3.9.4 has been left in tact to avoid breaking other things."
    echo "To remove it, please run pyenv uninstall 3.9.4"
}

function _upgrade(){
    systemctl --user -q stop mylar
    echo "Upgrading Mylarr"
    _download
    systemctl --user daemon-reload 
    systemctl --user restart mylar
    echo "Upgrade Complete!"
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

echo "Welcome to the Mylar3 installer..."
echo ""
echo "What do you like to do?"
echo ""
echo "install = Install Mylar"
echo "upgrade = Upgrade existing Mylar installation"
echo "uninstall = Completely removes Mylar"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            clear
            _install
            break
            ;;
        "uninstall")
            _remove
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
