#!/bin/bash
#############################################
#                                           #
#  Install NSI Presence server with RaspAP  #
#                                           #
#############################################


set -e


# functions
check_root() {
    if [ $(whoami) != "root" ]; then
        echo "[!] This program might be launched in root !"
        exit 1
    fi
}

all_args=$@

check_arg() {
    for arg in $all_args; do
        [[ "$arg" == "$1" ]] && return 0
    done
    return 1
}

configure_lighttpd() {
    # configure lighttpd to allow authorized pages and restrict the others
    captive_portal_urls="connectivitycheck\.gstatic\.com|connect\.rom\.miui\.com|clients3\.google\.com|www\.msftconnecttest\.com|captive\.apple\.com"
    cat > "/etc/lighttpd/conf-enabled/50-raspap-router.conf" <<- EOF
server.modules += (
    "mod_rewrite",
    "mod_proxy"
)

# captive portal Android / Apple / Windows
\$HTTP["host"] =~ "^($captive_portal_urls)$" {

    # check captive portal url
    \$HTTP["url"] =~ "^/(generate_204|redirect|hotspot-detect\.html)$" {
        # captive portal redirection
        url.redirect = ( ".*" => "/nsi-presence-words/index.html" )
    }
}

# redirect all to RaspAP
\$HTTP["host"] !~ "^($captive_portal_urls)$" {

    # ckeck if the url starts with (and skip redirection)
    \$HTTP["url"] =~ "^/(?!(dist|app|ajax|config|rootCA\.pem|nsi-presence-words)).*" {
        # raspap redirection
        url.rewrite-once = ( "^/(.*?)(\?.+)?$"=>"/index.php/\$1\$2" )
        server.error-handler-404 = "/index.php"
    }
}

# proxy /nsi-presence-words to Flask server on port $1
\$HTTP["url"] =~ "^/(favicon\.ico|envoyer|get_messages|moderer)$" {
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


# variables
workdir=$(pwd)
install_dir_src="/var/www/html"
install_dir="$install_dir_src/nsi-presence-words"
check_config_bin="$install_dir/bin/server-check_config.sh"


# help
if check_arg "--help"; then
    echo "Help:"
    echo "    --help    : help command"
    echo "    remove    : remove nsi-presence-words server"
    echo "    install   : install nsi-presence-words server"
    echo "    configure : configure the port of the  "
    echo "                nsi-presence-words server"
    exit 0
fi


# install
if check_arg "install"; then
    # check root
    check_root

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
            exit
        fi
    fi

    # install python for hosted server
    echo "[*] Install python3"
    apt install python3

    # clone project
    echo "[*] Installing server ..."
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

    # check config script
    chmod +x $check_config_bin
    cat > "/etc/systemd/system/nsi-presence-words-server-check_config.service" <<- EOF
[Unit]
Description=NSI Project server config checker
After=network.target

[Service]
Type=simple
User=root
ExecStart=$check_config_bin

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # create systemd service
    echo "[*] Create services"
    cat > "/etc/systemd/system/nsi-presence-words-server.service" <<- EOF
[Unit]
Description=NSI Project server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$install_dir
ExecStart=$install_dir/venv/bin/python3 serveur.py

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # modify DNS conf (redirect all urls)
    echo "[*] Configuring server ..."
    bash $check_config_bin

    # change lighttpd conf
    configure_lighttpd 5000

    # enable lighttpd proxy http
    lighty-enable-mod proxy || true
    lighty-enable-mod proxy_http || true
    service lighttpd force-reload
    systemctl restart lighttpd

    # enable and start service
    systemctl daemon-reload
    systemctl enable nsi-presence-words-server.service nsi-presence-words-server-check_config.service
    systemctl start nsi-presence-words-server.service nsi-presence-words-server-check_config.service
    echo "[*] nsi-presence-words-server started"

    echo "[+] nsi-presence-words words installed"


# remove
elif check_arg "remove"; then
    # check root
    check_root

    # remove project src
    rm -rf $install_dir

    # stop and disable service
    echo "[*] Removing nsi-presence-words-server ..."
    rm -f "/etc/systemd/system/nsi-presence-words-server.service"
    rm -f "/etc/systemd/system/nsi-presence-words-server-check_config.service"
    systemctl stop nsi-presence-words-server.service nsi-presence-words-server-check_config.service
    systemctl disable nsi-presence-words-server.service nsi-presence-words-server-check_config.service
    systemctl daemon-reload
    echo "[+] nsi-presence-words-server removed"

    # remove raspap
    if [ -f "src/bin/raspap.sh" ]; then
        echo "[*] Removing RaspAP ..."
        bash src/bin/raspap.sh remove
    else
        echo "[-] Cannot remove RaspAP"
        exit
    fi


elif check_arg "configure"; then
    # check root
    check_root

    # ask the new port
    echo "[*] Server configuration"
    read -p "[?] words-server port: " server_port
    read -p "[?] words-server moderation password: " modo_password
    read -p "[?] Apply configuration and restart server ? (y/n): " confirm && [[ $confirm == [yY] ]] || exit 1

    # configure port
    echo "[*] Apply new configuration"
    cat > "$install_dir/.env" <<- EOF
SERVER_PORT=$server_port
MODO_PASSWORD=$modo_password
EOF

    # qr code config
    echo "PORT=$server_port" > $workdir/qr_code/.env

    # reconfigure lighttpd for proxy
    configure_lighttpd $server_port
    systemctl restart lighttpd

    # restart server
    echo "[*] Restarting server ..."
    systemctl restart nsi-presence-words-server.service
    echo "[*] New configuration applied"
fi
