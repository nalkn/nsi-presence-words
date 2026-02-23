# Créé par Nathan BERGEON et Killian NALLET, le 07/02/2026 en Python 3.11.2
# Coding utf-8

# imports
import os
import sys
import json
import dotenv
from flask import Flask, request, send_from_directory, jsonify, session, redirect, url_for

# EXE configuration
if getattr(sys, 'frozen', False):
    base_path = sys._MEIPASS  # .exe
else:
    base_path = os.path.abspath(".") # .py

# init serveur
PORT = os.environ["PORT"] if dotenv.load_dotenv() else 5000
app = Flask(__name__)
app.secret_key = 'nsi_claudel_2026'

# json files
MOT_MAX_LENGTH = 25
DATA_FILE = "messages.json"
VALIDE_FILE = "valides.json"
REJETE_FILE = "rejetes.json"

for f_path in [DATA_FILE, VALIDE_FILE, REJETE_FILE]:
    if not os.path.exists(f_path):
        with open(f_path, "w") as f: 
            json.dump({"en_attente":[], "valides":[], "rejetes":[]} if "messages" in f_path else [], f)

# server paths
@app.route('/')
def index(): 
    return send_from_directory(base_path, 'index.html')

@app.route('/<path:p>')
def static_f(p): 
    return send_from_directory(base_path, p)

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        if request.form.get('password') == 'NSI':
            session['logged_in'] = True
            return redirect(url_for('admin'))
    return '<body style="background:#000814;color:white;display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;"><form method="post"><h2>Code :</h2><input type="password" name="password" autofocus><button type="submit">OK</button></form></body>'

@app.route('/admin')
def admin():
    if not session.get('logged_in'): 
        return redirect(url_for('login'))
    return send_from_directory(base_path, 'admin.html')

@app.route('/projecteur')
def projecteur(): 
    return send_from_directory(base_path, 'projecteur.html')

@app.route('/envoyer', methods=['POST'])
def envoyer():
    rq = request.form.get('message')
    if rq:
        with open(DATA_FILE, "r+") as f:
            data = json.load(f)
            new_id = len(data["en_attente"]) + len(data["valides"]) + len(data["rejetes"]) + 1
            data["en_attente"].append({"id": new_id, "texte": rq[:MOT_MAX_LENGTH]})
            f.seek(0); json.dump(data, f); f.truncate()
        return "OK"
    return "Err", 400

@app.route('/get_messages')
def get_messages():
    with open(DATA_FILE, "r") as f: 
        return jsonify(json.load(f))

@app.route('/moderer', methods=['POST'])
def moderer():
    if not session.get('logged_in'): 
        return "403", 403
    rq = request.json
    with open(DATA_FILE, "r+") as f:
        data = json.load(f)
        for msg in data["en_attente"]:
            if msg["id"] == rq['id']:
                dest = "valides" if rq['action'] == 'valider' else "rejetes"
                data[dest].append(msg)
                data["en_attente"].remove(msg)
                # Archivage dans les fichiers .json séparés
                f_archive = VALIDE_FILE if rq['action'] == 'valider' else REJETE_FILE
                with open(f_archive, "r+") as fa:
                    la = json.load(fa); la.append(msg)
                    fa.seek(0); json.dump(la, fa, indent=4); fa.truncate()
                break
        f.seek(0); json.dump(data, f); f.truncate()
    return "OK"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=PORT)

# ============================================================
# CREER UN EXE PORTABLE (VENV + EXE)
# ============================================================
# Créer l'environnement (Terminal dans le dossier du projet) :
#    python -m venv venv
#
# Activer l'environnement :
#    .\venv\Scripts\activate
#
# Installer les dépendances nécessaires :
#    pip install flask pyinstaller
#
# Créer l'EXE:
#    pyinstaller --onefile --add-data "index.html;." --add-data "admin.html;." --add-data "projecteur.html;." --add-data "style.css;." --add-data "admin-style.css;." --add-data "script.js;." --add-data "admin-script.js;." serveur.py
#
# Résultat : Ton EXE dans le dossier dist.
# ============================================================
