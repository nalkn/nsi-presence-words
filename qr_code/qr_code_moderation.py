import os
import dotenv
import qrcode

os.chdir(os.path.dirname(__file__))

PORT = os.environ["PORT"] if dotenv.load_dotenv() else 5000
base_url = f"http://10.3.141.1:{PORT}"

for name in ["admin", "projecteur"]:
    qr = qrcode.QRCode(
        version=None,  # taille automatique
        error_correction=qrcode.constants.ERROR_CORRECT_H,
        box_size=10,   # taille des carrés
        border=4       # bordure
    )

    qr.add_data(f"{base_url}/{name}")
    qr.make(fit=True)

    img = qr.make_image(fill_color="black", back_color="white")
    filename = f"qr_ap_word_{name}.png"
    img.save(filename)

    print(f"QR code : {filename}")
