import os
import qrcode

os.chdir(os.path.dirname(__file__))


# ap wifi
ssid = "Projet Présence"
password = "isidora_@954ght"
auth_type = "WPA2"  # WPA, WEP
wifi_string = f"WIFI:T:{auth_type};S:{ssid};P:{password};;"

qr = qrcode.QRCode(
    version=1,
    error_correction=qrcode.constants.ERROR_CORRECT_L,
    box_size=10,
    border=4,
)
qr.add_data(wifi_string)
qr.make(fit=True)

img = qr.make_image(fill_color="black", back_color="white")
filename = "qr_ap_wifi.png"
img.save(filename)

print(f"QR code Wi-Fi : {filename}")


# ap url
url = "http://10.3.141.1/nsi-presence-words/index.html"

qr = qrcode.QRCode(
    version=None,  # taille automatique
    error_correction=qrcode.constants.ERROR_CORRECT_H,
    box_size=10,   # taille des carrés
    border=4       # bordure
)

qr.add_data(url)
qr.make(fit=True)

img = qr.make_image(fill_color="black", back_color="white")
filename = "qr_ap_word_url.png"
img.save(filename)

print(f"QR code Url : {filename}")
