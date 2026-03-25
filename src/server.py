# Créé par Nathan BERGEON et Killian NALLET, le 07/02/2026 en Python 3.11.2
# Coding utf-8

# imports
import os
import sys
import json
import dotenv
from flask import Flask, Response, request, send_from_directory, jsonify, session, redirect, url_for

# EXE configuration
if getattr(sys, 'frozen', False):
    base_path = sys._MEIPASS  # .exe
else:
    base_path = os.path.dirname(__file__) # .py

# load configuration
dotenv.load_dotenv()
MOT_MAX_LENGTH = 25
SERVER_PORT = int(os.getenv("SERVER_PORT", "5000"))
MODO_USER = os.getenv("MODO_USER", "modo")
MODO_PASSWORD = os.getenv("MODO_PASSWORD", "modo")

# init serveur
app = Flask(__name__)
app.secret_key = 'nsi_claudel_2026'

# json files
data_path = os.path.join(base_path, "data")
if not os.path.exists(data_path):
    os.mkdir(data_path)

DATA_FILE = os.path.join(data_path, "messages.json")
VALIDE_FILE = os.path.join(data_path, "valides.json")
REJETE_FILE = os.path.join(data_path, "rejetes.json")

for f_path in [DATA_FILE, VALIDE_FILE, REJETE_FILE]:
    if not os.path.exists(f_path):
        with open(f_path, "w") as f:
            json.dump({"en_attente":[], "valides":[], "rejetes":[]} if "messages" in f_path else [], f)

def check_auth(auth):
    return auth.username == MODO_USER and auth.password == MODO_PASSWORD

# server paths
@app.route('/')
def index():
    return send_from_directory(base_path, 'index.html')

@app.route('/<path:p>')
def static_f(p):
    if p.endswith(".html") and p != "index.html": # restrict non-authorized access
        return Response(
            '403 Forbidden', 403
        )
    return send_from_directory(base_path, p)

@app.route('/moderation', methods=['GET', 'POST'])
def moderation():
    auth = request.authorization
    if not auth or not check_auth(auth):
        return Response(
            'Mot de passe requis', 401,
            {'WWW-Authenticate': 'Basic realm="Login Required"'}
        )
    return send_from_directory(base_path, 'moderation.html')

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
    auth = request.authorization
    if not auth or not check_auth(auth):
        return "403", 403

    rq = request.json
    msg_id = rq['id']
    action = rq['action']

    with open(DATA_FILE, "r+") as f:
        d = json.load(f)

        msg_found = None
        src_list = None
        
        for cle in ["en_attente", "valides", "rejetes"]:
            for m in d[cle]:
                if m["id"] == msg_id:
                    msg_found = m
                    src_list = cle
                    break
            if msg_found: 
                break # stop search if found
                
        # if message found, move it
        if msg_found:
            liste_destination = None
            if action == 'valider': liste_destination = "valides"
            elif action == 'supprimer': liste_destination = "rejetes"
            elif action in ['annuler_valide', 'annuler_rejete']: liste_destination = "en_attente"
            
            if liste_destination:
                # move word to new list
                d[src_list].remove(msg_found)
                d[liste_destination].append(msg_found)
                
                # save messages.json
                f.seek(0)
                json.dump(d, f, indent=4)
                f.truncate()
                
                # synchronisation
                with open(VALIDE_FILE, "w") as f_val:
                    json.dump(d["valides"], f_val, indent=4)
                with open(REJETE_FILE, "w") as f_rej:
                    json.dump(d["rejetes"], f_rej, indent=4)

    return "OK"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=SERVER_PORT)
