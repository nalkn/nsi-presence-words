#!/bin/bash
################################
#                              #
#  Configure RaspAp on the pi  #
#                              #
################################


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

check_no_args() {
    [[ "$all_args" == "" ]] && return 0
    return 1
}

stop_raspap_restore_dns() {
    # temporary stop raspap
    systemctl stop lighttpd hostapd dnsmasq raspapd

    # restore original DNS config
    cat >> "/etc/resolv.conf" <<- EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
}


# no args
if check_no_args; then
    echo "This program need args to run"
    exit 1
fi


# help
if check_arg "--help"; then
    echo "Help:"
    echo "    --help  : help command"
    echo "    install : install raspap"
    echo "    remove  : remove raspap"
    echo "    restart : restart raspap"
    echo "    stop    : stop raspap and restore internet connexion"
    exit 0
fi


# install
if check_arg "install"; then
    curl -sL https://install.raspap.com | bash

    echo "[+] RaspAP installed"


# remove
elif check_arg "remove"; then
    # check root
    check_root

    # stop raspap
    stop_raspap_restore_dns

    # remove raspap
    systemctl disable lighttpd hostapd dnsmasq raspapd
    apt purge lighttpd hostapd dnsmasq -y

    # remove raspap config
    rm -rf /var/www/html
    rm -rf /etc/dnsmasq.d
    rm -rf /etc/hostapd
    rm -rf /etc/raspap

    echo "[+] RaspAP removed"


# restart
elif check_arg "restart"; then
    # check root
    check_root

    # diasble temporary raspap
    systemctl restart lighttpd hostapd dnsmasq raspapd

    echo "[+] RaspAP restarted"


# stop
elif check_arg "stop"; then
    # check root
    check_root

    # stop raspap
    stop_raspap_restore_dns

    echo "[+] RaspAP stopped"


# no valid command
else
    echo "$1 arg is not valid"
fi
