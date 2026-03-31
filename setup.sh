#!/bin/bash
#############################################
#                                           #
#  Install NSI Presence server with RaspAP  #
#                                           #
#############################################


set -e


# variables
workdir=$(pwd)
install_dir_src="/var/www/html"
install_dir="$install_dir_src/nsi-presence-words"
dir_data="$workdir/src/data"
check_config_bin="$install_dir/bin/server-check_config.sh"

default_port="5000"
default_user="modo"
default_password="modo"


# functions
print_usage() {
    echo "Usage:"
    echo "    install   : install nsi-presence-words server"
    echo "    configure : configure the port of the  "
    echo "                nsi-presence-words server"
    echo "    update    : update nsi-presence-words server"
    echo "    remove    : remove nsi-presence-words server"
    echo "    --help    : help command"
    exit 0
}

all_args=$@
action=$1
next_arg=$2

check_args() {
    # only use action
    if [ ! -z "$next_arg" ]; then
        echo "[!] Invalid usage : $0 $all_args"
        return 1
    fi

    # valid action
    for arg in "install" "configure" "update" "remove" "--help"; do
        [[ "$action" == "$arg" ]] && return 0
    done
    echo "[!] Invalid action : $action"
    return 1
}

install_src() {
    rm -rf $install_dir
    cp -a src $install_dir

    # create pyton venv
    echo "[*] Creating python venv"
    cd $install_dir
    python3 -m venv venv
    echo "[*] Installing python requirements"
    ./venv/bin/pip3 install -r $workdir/requirements.txt

    # give good perms
    chown -R www-data:www-data $install_dir
    chmod 775 $install_dir
    chmod +x $check_config_bin $workdir/setup.sh
}

configure_credentials() {
    # configure port and moderation data
    cat > "$install_dir/.env" <<- EOF
SERVER_PORT='$1'
MODO_USER='$2'
MODO_PASSWORD='$3'
EOF

    # qr code config
    echo "PORT=$1" > $workdir/qr_code/.env
}

load_credentials() {
    # backup env file
    if [ -f "$install_dir/.env" ]; then
        cp "$install_dir/.env" "$workdir/.env.bak"
    fi

    # load port and moderation data
    if [ -f "$workdir/.env.bak" ]; then
        source "$workdir/.env.bak"
        default_port=$SERVER_PORT
        default_user=$MODO_USER
        default_password=$MODO_PASSWORD
    fi
}

load_captive_portal_config() {
    # load hosts
    if [ -f "$dir_data/captive_portal_hosts.txt" ]; then
        captive_portal_hosts=$(grep -v '^$' "$dir_data/captive_portal_hosts.txt" | grep -v '^#' | sed 's/\./\\./g' | paste -sd '|' -)
    else
        echo "[-] captive_portal_hosts.txt not found !"
        exit 1
    fi
}

configure_lighttpd() {
    # configure lighttpd to allow authorized pages and restrict the others
    cat > "/etc/lighttpd/conf-enabled/50-raspap-router.conf" <<- EOF
server.modules += (
    "mod_rewrite",
    "mod_proxy"
)

# captive portal Android / Apple / Windows - redirect all URLs from these hosts
\$HTTP["host"] =~ "^($captive_portal_hosts)$" {
    # redirect only when on a non-NSI-PRESENCE path, to avoid redirect loops
    \$HTTP["url"] !~ "^/nsi-presence-words/" {
        url.redirect = ( ".*" => "http://10.3.141.1/nsi-presence-words/index.html" )
    }
}

# redirect all to RaspAP
\$HTTP["host"] !~ "^($captive_portal_hosts)$" {
    # ckeck if the url starts with (and skip redirection)
    \$HTTP["url"] =~ "^/(?!(dist|app|ajax|config|rootCA\.pem|nsi-presence-words)).*" {
        # raspap redirection
        url.rewrite-once = ( "^/(.*?)(\?.+)?$"=>"/index.php/\$1\$2" )
        server.error-handler-404 = "/index.php"
    }
}

# proxy /nsi-presence-words to Flask server on port $1
\$HTTP["url"] =~ "^/(favicon\.ico|envoyer|get_messages|moderer|vider_rejetes)$" {
    # rewrite url
    url.rewrite-once = (
        "^/(/.*|)$" => "\1"
    )

    # redirect to server
    proxy.server = (
        "" => ( ( "host" => "127.0.0.1", "port" => $1 ) )
    )
}

# Filter Flask server pages on /nsi-presence-words
\$HTTP["url"] =~ "^/nsi-presence-words" {
    # allow only the word page
    \$HTTP["url"] !~ "/(index\.html|style\.css)$" {
        url.redirect = ( ".*" => "/nsi-presence-words/index.html" )
    }
}
EOF
}


# check args
if ! check_args; then
    print_usage
fi


# help
if [ "$action" == "--help" ]; then
    print_usage
fi


# check root
if [ $(whoami) != "root" ]; then
    echo "[!] This program need root !"
    exit 1
fi


# load captive portal config
load_captive_portal_config


# install
if [ "$action" == "install" ]; then
    # check raspap
    if ! [ -d "/etc/raspap" ]; then
        echo "[-] RaspAP is not installed !"
        if [ -f "src/bin/raspap.sh" ]; then
            echo "[*] Installing RaspAP ..."
            bash src/bin/raspap.sh install
            echo ""
            echo ""
        else
            echo "[-] Cannot install RaspAP"
            exit 1
        fi
    fi

    # install python for hosted server
    echo "[*] Install python3"
    apt install python3

    # install src
    echo "[*] Installing server ..."
    install_src

    # check config script
    cat > "/etc/systemd/system/nsi-presence-words-server-check_config.service" <<- EOF
[Unit]
Description=NSI Project server config checker
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=$check_config_bin

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    cat > "/etc/systemd/system/nsi-presence-words-server-check_config.timer" <<- EOF
[Unit]
Description=Run the Project configuration check

[Timer]
OnBootSec=1min
OnUnitActiveSec=2min
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # create systemd service
    cat > "/etc/systemd/system/nsi-presence-words-server.service" <<- EOF
[Unit]
Description=NSI Project server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$install_dir
ExecStart=$install_dir/venv/bin/python3 server.py

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # configure server with credentials
    echo "[*] Applying default configuration"
    configure_credentials $default_port $default_user $default_password

    # change lighttpd conf
    configure_lighttpd $default_port

    # enable lighttpd proxy http
    lighty-enable-mod proxy || true
    lighty-enable-mod proxy_http || true
    service lighttpd force-reload
    systemctl restart lighttpd

    # enable and start service
    systemctl daemon-reload
    systemctl enable nsi-presence-words-server.service nsi-presence-words-server-check_config.timer
    systemctl start nsi-presence-words-server.service nsi-presence-words-server-check_config.timer
    echo "[*] nsi-presence-words-server started"

    echo "[+] nsi-presence-words words installed"


# configure
elif [ "$action" == "configure" ]; then
    # ask the new port
    echo "[*] NSI Words Server configuration"
    read -p "[?] port: " server_port
    read -p "[?] moderation user: " modo_user
    read -p "[?] moderation password: " modo_password
    echo ""
    read -p "[?] Apply configuration and restart server ? (y/n): " confirm && [[ $confirm == [yY] ]] || exit 1

    # configure server with credentials
    echo "[*] Applying new configuration"
#    configure_credentials $server_port $modo_user $modo_password

    # reconfigure lighttpd for proxy
    configure_lighttpd $server_port
    systemctl restart lighttpd

    # restart server
    echo "[*] Restarting server ..."
    systemctl restart nsi-presence-words-server.service nsi-presence-words-server-check_config.timer
    echo "[*] New configuration applied"


# update
elif [ "$action" == "update" ]; then
    echo "[*] Update need internet connexion"

    # update raspap
    read -p "[?] Update RaspAP ? (y/n): " confirm
    if [[ $confirm == [yY] ]]; then
        curl -sL https://install.raspap.com | bash -s -- --upgrade
    fi

    # update server
    echo "[*] Updating server ..."
    systemctl stop nsi-presence-words-server.service nsi-presence-words-server-check_config.timer
    su $SUDO_USER -c "git fetch origin && git reset --hard origin/main" > /dev/null 2>&1

    # load used credentials
    load_credentials

    # update src
    install_src

    # configure server with credentials
    echo "[*] Restoring configuration"
    configure_credentials $default_port $default_user $default_password
    if [ -f "$workdir/.env.bak" ]; then
        rm "$workdir/.env.bak"
    fi

    # change lighttpd conf
    configure_lighttpd $default_port

    # restart server
    echo "[*] Restarting server ..."
    systemctl restart lighttpd
    systemctl start nsi-presence-words-server.service nsi-presence-words-server-check_config.timer
    echo "[*] NSI Words Server is up-to-date"


# remove
elif [ "$action" == "remove" ]; then
    echo "[*] Removing nsi-presence-words-server ..."

    # remove project src
    rm -rf $install_dir

    # stop and disable service
    rm -f "/etc/systemd/system/nsi-presence-words-server.service"
    rm -f "/etc/systemd/system/nsi-presence-words-server-check_config.service" "/etc/systemd/system/nsi-presence-words-server-check_config.timer"
    systemctl stop nsi-presence-words-server.service nsi-presence-words-server-check_config.timer
    systemctl disable nsi-presence-words-server.service nsi-presence-words-server-check_config.timer
    systemctl daemon-reload
    echo "[+] nsi-presence-words-server removed"

    # remove raspap
    if [ -f "src/bin/raspap.sh" ]; then
        echo "[*] Removing RaspAP ..."
        bash src/bin/raspap.sh remove
    else
        echo "[-] Cannot remove RaspAP"
        exit 1
    fi
fi
