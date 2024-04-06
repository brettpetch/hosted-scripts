#!/bin/bash
## Brett 2021
user=$(whoami)
mkdir -p $HOME/.logs/
touch "$HOME/.logs/lounge.log"
log="$HOME/.logs/lounge.log"

function _deps() {
    ## Function for installing nvm.
    if [[ ! -d $HOME/.nvm ]]; then
        echo "Installing node"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash >> "$log" 2>&1
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
    echo "Installing Yarn"
    npm install -g yarn >> "$log" 2>&1 || {
        echo "Yarn failed to install"
        exit 1
    }
    echo "Yarn installed."
}

function port() {
    ## Function for generating a random unused port
    LOW_BOUND=$1
    UPPER_BOUND=$2
    comm -23 <(seq ${LOW_BOUND} ${UPPER_BOUND} | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | shuf | head -n 1
}

function ssl_gen() {
	echo "Generating SSL keys"
	country="NL"
	state="Amsterdam"
	locality="North Holland"
	organization="$(hostname -f)"
	organizationalunit="$user"
	commonname="$user"
	ssl_password=""
	mkdir -p "/home/$user/.ssl/"
	openssl genrsa -out "$HOME/.ssl/$user-self-signed.key" 2048 >> /dev/null 2>&1
	openssl req -new -key "$HOME/.ssl/$user-self-signed.key" -out "$HOME/.ssl/$user-self-signed.csr" -passin pass:$ssl_password -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname" >> /dev/null 2>&1
	openssl x509 -req -days 1095 -in "$HOME/.ssl/$user-self-signed.csr" -signkey "$HOME/.ssl/$user-self-signed.key" -out "$HOME/.ssl/$user-self-signed.crt" >> /dev/null 2>&1
	chown -R "$user": "$HOME/.ssl"
	chmod 750 "$HOME/.ssl"
	echo "SSL Key Generated"
}

function _install() {
    ssl_gen
    ## Function for node install of TheLounge
    echo "Installing The Lounge"
    yarn --non-interactive global add thelounge >> "$log" 2>&1
    echo "Configuring The Lounge"
    mkdir -p "$HOME/.thelounge/"
    port=($(port 10000 12000))
    cat > "$HOME/.thelounge/config.js" << EOF
"use strict";
module.exports = {
	//
	// Set the server mode.
	// Public servers does not require authentication.
	//
	// Set to 'false' to enable users.
	//
	// @type     boolean
	// @default  true
	//
	public: false,
	//
	// IP address or hostname for the web server to listen on.
	// Setting this to undefined will listen on all interfaces.
	//
	// @type     string
	// @default  undefined
	//
	host: undefined,
	//
	// Set the port to listen on.
	//
	// @type     int
	// @default  9000
	//
	port: ${port},
	//
	// Set the local IP to bind to for outgoing connections. Leave to undefined
	// to let the operating system pick its preferred one.
	//
	// @type     string
	// @default  undefined
	//
	bind: undefined,
	//
	// Sets whether the server is behind a reverse proxy and should honor the
	// X-Forwarded-For header or not.
	//
	// @type     boolean
	// @default  false
	//
	reverseProxy: false,
	//
	// Set the default theme.
	// Find out how to add new themes at https://thelounge.github.io/docs/packages/themes
	//
	// @type     string
	// @default  "example"
	//
	theme: "thelounge-theme-zenburn",
	//
	// Prefetch URLs
	//
	// If enabled, The Lounge will try to load thumbnails and site descriptions from
	// URLs posted in channels.
	//
	// @type     boolean
	// @default  false
	//
	prefetch: true,
	//
	// Store and proxy prefetched images and thumbnails.
	// This improves security and privacy by not exposing client IP address,
	// and always loading images from The Lounge instance and making all assets secure,
	// which in result fixes mixed content warnings.
	//
	// If storage is enabled, The Lounge will fetch and store images and thumbnails
	// in ~/.lounge/storage folder, or %HOME%/storage if --home is used.
	//
	// Images are deleted when they are no longer referenced by any message (controlled by maxHistory),
	// and the folder is cleaned up on every The Lounge restart.
	//
	// @type     boolean
	// @default  false
	//
	prefetchStorage: false,
	//
	// Prefetch URLs Image Preview size limit
	//
	// If prefetch is enabled, The Lounge will only display content under the maximum size.
	// Specified value is in kilobytes. Default value is 512 kilobytes.
	//
	// @type     int
	// @default  512
	//
	prefetchMaxImageSize: 4096,
	//
	// Display network
	//
	// If set to false network settings will not be shown in the login form.
	//
	// @type     boolean
	// @default  true
	//
	// displayNetwork: true,
	//
	// Lock network
	//
	// If set to true, users will not be able to modify host, port and tls
	// settings and will be limited to the configured network.
	//
	// @type     boolean
	// @default  false
	//
	lockNetwork: false,
	//
	// Hex IP
	//
	// If enabled, clients' username will be set to their IP encoded has hex.
	// This is done to share the real user IP address with the server for host masking purposes.
	//
	// @type     boolean
	// @default  false
	//
	useHexIp: false,
	//
	// WEBIRC support
	//
	// If enabled, The Lounge will pass the connecting user's host and IP to the
	// IRC server. Note that this requires to obtain a password from the IRC network
	// The Lounge will be connecting to and generally involves a lot of trust from the
	// network you are connecting to.
	//
	// Format (standard): {"irc.example.net": "hunter1", "irc.example.org": "passw0rd"}
	// Format (function):
	//   {"irc.example.net": function(client, args, trusted) {
	//       // here, we return a webirc object fed directly to \$(irc-framework)
	//       return {username: "thelounge", password: "hunter1", address: args.ip, hostname: "webirc/"+args.hostname};
	//   }}
	//
	// @type     string | function(client, args):object(webirc)
	// @default  null
	webirc: null,
	//
	// Maximum number of history lines per channel
	//
	// Defines the maximum number of history lines that will be kept in
	// memory per channel/query, in order to reduce the memory usage of
	// the server. Setting this to -1 will keep unlimited amount.
	//
	// @type     integer
	// @default  10000
	maxHistory: 10000,
	//
	// Set socket.io transports
	//
	// @type     array
	// @default  ["polling", "websocket"]
	//
	transports: ["polling", "websocket"],
	//
	// Run The Lounge using encrypted HTTP/2.
	// This will fallback to regular HTTPS if HTTP/2 is not supported.
	//
	// @type     object
	// @default  {}
	//
	https: {
		//
		// Enable HTTP/2 / HTTPS support.
		//
		// @type     boolean
		// @default  false
		//
		enable: true,
		//
		// Path to the key.
		//
		// @type     string
		// @example  "sslcert/key.pem"
		// @default  ""
		//
		key: "/home/$user/.ssl/$user-self-signed.key",
		//
		// Path to the certificate.
		//
		// @type     string
		// @example  "sslcert/key-cert.pem"
		// @default  ""
		//
		certificate: "/home/$user/.ssl/$user-self-signed.crt",
		//
		// Path to the CA bundle.
		//
		// @type     string
		// @example  "sslcert/bundle.pem"
		// @default  ""
		//
		ca: ""
	},
	//
	// Run The Lounge with identd support.
	//
	// @type     object
	// @default  {}
	//
	identd: {
		//
		// Run the identd daemon on server start.
		//
		// @type     boolean
		// @default  false
		//
		enable: false,
		//
		// Port to listen for ident requests.
		//
		// @type     int
		// @default  113
		//
		port: 113
	},
	//
	// Enable oidentd support using the specified file
	//
	// Example: oidentd: "~/.oidentd.conf",
	//
	// @type     string
	// @default  null
	//
	oidentd: null,
	//
	// LDAP authentication settings (only available if public=false)
	// @type    object
	// @default {}
	//
	ldap: {
		//
		// Enable LDAP user authentication
		//
		// @type     boolean
		// @default  false
		//
		enable: false,
		//
		// LDAP server URL
		//
		// @type     string
		//
		url: "ldaps://example.com",
		//
		// LDAP base dn
		//
		// @type     string
		//
		baseDN: "ou=accounts,dc=example,dc=com",
		//
		// LDAP primary key
		//
		// @type     string
		// @default  "uid"
		//
		primaryKey: "uid"
	},
	// Extra debugging
	//
	// @type     object
	// @default  {}
	//
	debug: {
		// Enables extra debugging output provided by irc-framework.
		//
		// @type     boolean
		// @default  false
		//
		ircFramework: false,
		// Enables logging raw IRC messages into each server window.
		//
		// @type     boolean
		// @default  false
		//
		raw: false,
	},
};
EOF

    mkdir -p "$HOME/.thelounge/users/"
    bash -c "thelounge install thelounge-theme-zenburn"
    # Figger out if hostname is Swizzin, LW Swizzin, or SBIO
    echo "thelounge will run on ${port}"
    echo "Your Lounge instance is up and running at https://$(hostname -f):${port}"
}
function _systemd() {
    ## Function responsible for everything systemd
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/lounge.service" << EOSD
[Unit]
Description=The Lounge IRC client
After=znc.service
[Service]
Type=simple
Environment=NODE_VERSION=$(node -v | cut -d "v" -f 2 | cut -d "." -f 1)
ExecStart=$HOME/.nvm/nvm-exec $HOME/.yarn/bin/thelounge start
Restart=on-failure
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3
[Install]
WantedBy=default.target
EOSD
    systemctl --user enable -q --now lounge.service >> "$log" 2>&1 || echo "Failed to start TheLounge, please check logs."
}

function _adduser() {
    read -rep "Please set a password for your The Lounge user, ${user}>  " -i "" password
    crypt=$(node $HOME/.config/yarn/global/node_modules/bcryptjs/bin/bcrypt "${password}")
    cat > "$HOME/.thelounge/users/${user}.json" << EOU
{
	"password": "${crypt}",
	"log": true,
	"awayMessage": "",
	"networks": [],
	"sessions": {}
}
EOU
}

function _remove() {
    ## Function Removes lounge and config files.
    systemctl --user disable -q lounge >> /dev/null 2>&1
    systemctl --user stop -q lounge

    npm uninstall -g thelounge --save >> /dev/null 2>&1
    yarn --non-interactive global remove thelounge

    rm -rf "$HOME/.thelounge" # just in case

    rm -f "$HOME/.config/systemd/user/lounge.service"
    rm -f "$HOME/install/.lounge.lock"
}

function upgrade() {
    echo "Upgrading The Lounge"
    echo "Stopping lounge.service"
    systemctl --user -q stop lounge
    npm remove -g thelounge
    yarn --non-interactive global add thelounge 
    echo "Starting lounge.service"
    systemctl --user -q start lounge
    echo "The Lounge has been Upgraded."
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

echo "Welcome to The Lounge installer..."
echo ""
echo "What do you like to do?"
echo "Logs are stored at ${log}"
echo "install = Install The Lounge"
echo "uninstall = Completely removes The Lounge"
echo "exit = Exits Installer"
while true; do
    read -r -p "Enter it here: " choice
    case $choice in
        "install")
            _deps
            _install
            _systemd
            _adduser
            break
            ;;
        "uninstall")
            _remove
            break
            ;;
        "upgrade")
            upgrade
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
