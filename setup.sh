#!/bin/bash
#######################################
#                                     #
#  Install project server and RaspAP  #
#                                     #
#######################################


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

workdir=$(pwd)


# help
if check_arg "--help"; then
    echo "Help:"
    echo "    --help  : help command"
    echo "    install : install nsi-presence-words server"
    echo "    remove  : remove nsi-presence-words server"
    exit 0
fi


# install
if check_arg "install"; then
    # check root
    check_root

    # check raspap
    if ! [ -d "/etc/raspap" ]; then
        echo "[-] RaspAP is not installed !"
        if [ -f "./raspap.sh" ]; then
            echo "[*] Installing RaspAP ..."
            bash ./raspap.sh install
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
    rm -rf /var/www/html/nsi-presence-words
    cp -a src /var/www/html/nsi-presence-words

    # create pyton venv
    echo "[*] Creating python venv"
    cd /var/www/html/nsi-presence-words
    python3 -m venv venv

    echo "[*] Installing python requirements"
    ./venv/bin/pip3 install -r $workdir/requirements.txt

    # give good perms
    cd /var/www/html/
    chown -R www-data:www-data nsi-presence-words
    chmod 775 /var/www/html/nsi-presence-words

    # modify DNS conf (redirect all urls)
    echo "[*] Configuring server ..."
    cat >> "/etc/dnsmasq.d/090_wlan0.conf" <<- 'EOF'

# Redirect DNS to the Pi (captive portal detection)
address=/#/10.3.141.1

# Captive Portal Hint (Android / certains OS modernes)
#dhcp-option=114,http://10.3.141.1/
EOF
    systemctl restart dnsmasq

    # change lighttpd conf
    cat > "/etc/lighttpd/conf-enabled/50-raspap-router.conf" <<- 'EOF'
server.modules += (
    "mod_rewrite",
    "mod_proxy"
)

# captive portal Android / Apple / Windows
$HTTP["host"] =~ "^(connectivitycheck\.gstatic\.com|www\.msftconnecttest\.com|captive\.apple\.com)$" {

    # check captive portal url
    $HTTP["url"] =~ "^/(generate_204|redirect|hotspot-detect\.html)$" {
        # captive portal redirection
        url.redirect = ( ".*" => "/nsi-presence-words/index.html" )
    }
}

# redirect all to RaspAP
$HTTP["host"] !~ "^(connectivitycheck\.gstatic\.com|www\.msftconnecttest\.com|captive\.apple\.com)$" {

    # ckeck if the url starts with (and skip)
    $HTTP["url"] =~ "^/(?!(dist|app|ajax|config|rootCA\.pem|nsi-presence-words)).*" {
        # raspap redirection
        url.rewrite-once = ( "^/(.*?)(\?.+)?$"=>"/index.php/$1$2" )
        server.error-handler-404 = "/index.php"
    }
}

# proxy /nsi-presence-words to Flask server on port 5000
$HTTP["url"] =~ "^/(favicon\.ico|envoyer|get_messages|moderer)$" {
    # rewrite url
    url.rewrite-once = (
        "^/(/.*|)$" => "\1"
    )

    # redirect to server
    proxy.server = (
        "" => ( ( "host" => "127.0.0.1", "port" => 5000 ) )
    )
}
EOF

    # enable lighttpd proxy http
    lighty-enable-mod proxy || true
    lighty-enable-mod proxy_http || true
    systemctl restart lighttpd
    service lighttpd force-reload

    # create a script to check the config at reboot
    cat > "/usr/local/bin/nsi-server-check_config.sh" <<- 'EOF'
#!/bin/bash

FILE="/etc/dnsmasq.d/090_wlan0.conf"
LINE="address=/#/10.3.141.1"

# check config
if ! grep -Fxq "$LINE" "$FILE"; then
    echo "[INFO] Ligne absente. Ajout en cours..."
    echo "$LINE" >> "$FILE"
   
    # restart dnsmasq
    systemctl restart dnsmasq
    echo "[OK] line added and dnsmasq restarted."
else
    echo "[OK] config ok."
fi
EOF
    chmod +x /usr/local/bin/nsi-server-check_config.sh

    # create systemd service to run vnc
    echo "[*] Creating service"
    cat > "/etc/systemd/system/nsi-presence-words-server.service" <<- EOF
[Unit]
Description=NSI Project server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/html/nsi-presence-words
ExecStart=/var/www/html/nsi-presence-words/venv/bin/python3 serveur.py

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    cat > "/etc/systemd/system/nsi-presence-words-server-check_config.service" <<- EOF
[Unit]
Description=NSI Project server config checker
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/nsi-server-check_config.sh

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF


    # enable and start service
    systemctl daemon-reload
    systemctl enable nsi-presence-words-server.service
    systemctl enable nsi-presence-words-server-check_config.service
    systemctl start nsi-presence-words-server.service
    systemctl start nsi-presence-words-server-check_config.service
    echo "[*] nsi-presence-words-server started"

    echo "[+] nsi-presence-words words installed"

# remove
elif check_arg "remove"; then
    # check root
    check_root

    # remove project src
    rm -rf /var/www/html/nsi-presence-words

    # stop and disable service
    echo "[*] Removing nsi-presence-words-server ..."
    rm -f "/etc/systemd/system/nsi-presence-words-server.service"
    rm -f "/etc/systemd/system/nsi-presence-words-server-check_config.service"
    systemctl stop nsi-presence-words-server.service
    systemctl stop nsi-presence-words-server-check_config.service
    systemctl disable nsi-presence-words-server.service
    systemctl disable nsi-presence-words-server-check_config.service
    rm -f /usr/local/bin/nsi-server-check_config.sh
    systemctl daemon-reload
    echo "[+] nsi-presence-words-server removed"

    # remove raspap
    if [ -f "./raspap.sh" ]; then
        echo "[*] Removing RaspAP ..."
        bash ./raspap.sh remove
    else
        echo "[-] Cannot remove RaspAP"
        exit
    fi
fi
