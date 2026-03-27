#!/bin/bash

MODIFIED=false

# check config
FILE="/etc/dnsmasq.d/090_wlan0.conf"
CHECK_LINE="address=/#/10.3.141.1"
DEL_LINE="dhcp-option=6,9.9.9.9,1.1.1.1"

# add line
if ! grep -Fxq "$CHECK_LINE" "$FILE"; then
    echo "[INFO] Adjust dnmasq config"
    cat >> "/etc/dnsmasq.d/090_wlan0.conf" <<- 'EOF'

# Redirect DNS to the Pi (captive portal detection)
address=/#/10.3.141.1
EOF
    MODIFIED=true
fi

# del line
if grep -Fxq "$DEL_LINE" "$FILE"; then
    echo "[INFO] Removing external DNS option"
    sed -i "\|^$DEL_LINE$|d" "$FILE"
    MODIFIED=true
fi

# restart dnsmasq
if $MODIFIED; then
    systemctl reload dnsmasq
fi
