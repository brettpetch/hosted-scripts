#!/bin/bash
# Thanks to MrNobody#2787 on HBD Discord for parts of the install function
function _install() {
    ###
    # Get mkvtoolnix & mkvtoolnix-gui
    ###
    os_release=$(
        source /etc/os_release
        printf '%s' "$VERSION_ID"
    )
    os_codename=$(
        source /etc/os_release
        printf '%s' "$VERSION_CODENAME"
    )
    ver=$(git ls-remote -q -t --refs https://gitlab.com/mbunkus/mkvtoolnix.git | awk '{sub("refs/tags/", ""); print $2 }' | awk '!/^$/' | sort -rV | head -n 1)
    wget "https://mkvtoolnix.download/debian/pool/${os_codename,,}/main/m/mkvtoolnix/mkvtoolnix_${ver//release-}-0~debian${os_release}bunkus01_amd64.deb"

    ###
    # Get some dependencies (which thrown errors when trying to launch mkvtoolnix-gui)
    ###
    
    apt-get download libqt5multimedia5

    ###
    # Install
    ###

    mkdir -p "${HOME}/.local/"
    dpkg-deb -x "*.deb" "${HOME}/.local/"

    ###
    # Cleanup
    ###
    cd ${HOME}
    rm -rf tmp

    ###
    # Run
    ###

    echo "" >> ${HOME}/.profile
    echo "export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH}:\${HOME}/.local/usr/lib/:\${HOME}/.local/usr/lib/x86_64-linux-gnu/" >> ${HOME}/.profile
}

