#!/bin/bash
# qbit_manage barebones installer

export user=$(whoami)
mkdir -p "$HOME/.logs/"
export log="$HOME/.logs/qbit_manage.log"
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
    versions=$("$HOME/.local/opt/pyenv/bin/pyenv" versions 2>> "$log")
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

function _install() {
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
    
    if [[ ! -d "$HOME/.local/opt/pyenv" ]]; then
        echo "Installing pyenv..."
        pyenv_install
    fi
    echo "Starting installation of qbit_manage."
    mkdir -p "$HOME/.venv/"
    pyenv_install_version 3.10.9
    pyenv_create_venv 3.10.9 "$HOME/.venv/qbit_manage"
    mkdir -p "$HOME/scripts"
    echo "Cloning qbit_manage"
    git clone "https://github.com/StuffAnThings/qbit_manage" "$HOME/scripts/qbit_manage" >> "$log" 2>&1
    echo "Installing qbit_manage requirements"
    "$HOME/.venv/qbit_manage/bin/pip" install -U pip >> "$log" 2>&1
    "$HOME/.venv/qbit_manage/bin/pip" install wheel >> "$log" 2>&1
    "$HOME/.venv/qbit_manage/bin/pip3" install "$HOME/scripts/qbit_manage/" >> "$log" 2>&1
}

function _upgrade() {
  git -C "$HOME/scripts/qbit_manage" pull >> "$log" 2>&1
  "$HOME/.venv/qbit_manage/bin/pip" install -U pip >> "$log" 2>&1
  "$HOME/.venv/qbit_manage/bin/pip3" install "$HOME/scripts/qbit_manage/" >> "$log" 2>&1
}

function _remove() {
  rm -rf "$HOME/scripts/qbit_manage"
  rm -rf "$HOME/.venv/qbit_manage"
}

echo "Welcome to the qbit_manage installer..."
echo ""
echo "What do you like to do?"
echo ""
echo "install = Install qbit_manage"
echo "upgrade = Upgrade existing qbit_manage installation"
echo "uninstall = Completely removes qbit_manage"
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
