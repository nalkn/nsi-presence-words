#!/bin/bash

set -e

# check root
if [ $(whoami) != "root" ]; then
    echo "[!] This program need root !"
    exit 1
fi

mkdir -p /var/log/lighttpd
chmod 750 /var/log/lighttpd
chown www-data:www-data /var/log/lighttpd

mv /etc/lighttpd/conf-enabled/50-raspap-router.conf /etc/lighttpd/conf-enabled/50-raspap-router.conf.bak
cat > "/etc/lighttpd/conf-enabled/50-raspap-router.conf" <<- EOF
server.modules += ( "mod_accesslog" )
accesslog.filename = "/var/log/lighttpd/access.log"
EOF
systemctl restart lighttpd

tail -f /var/log/lighttpd/access.log || true
rm -f /var/log/lighttpd/access.log

# not run
mv /etc/lighttpd/conf-enabled/50-raspap-router.conf.bak /etc/lighttpd/conf-enabled/50-raspap-router.conf
systemctl restart lighttpd
