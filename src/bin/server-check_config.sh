#!/bin/bash

FILE="/etc/dnsmasq.d/090_wlan0.conf"
CHECKLINE="address=/#/10.3.141.1"

# check config
if ! grep -Fxq "$CHECKLINE" "$FILE"; then
    echo "[INFO] Adjust dnmasq config"
    cat >> "/etc/dnsmasq.d/090_wlan0.conf" <<- 'EOF'

# Redirect DNS to the Pi (captive portal detection)
address=/#/10.3.141.1

# Captive Portal Hint (Android / modern OS)
#dhcp-option=114,http://10.3.141.1/
EOF

    # restart dnsmasq
    systemctl restart dnsmasq
fi
