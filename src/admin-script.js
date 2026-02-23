let dernierContenu = ""; // Variable pour stocker l'état précédent

function fetchMessages() {
    fetch('/get_messages')
        .then(res => res.json())
        .then(data => {
            const container = document.getElementById('list-container');
            const count = document.getElementById('msg-count');
            const messages = data.en_attente;

            // Mise à jour du compteur (ça, ça ne fait pas sauter la page)
            count.innerText = messages.length;

            // On crée le HTML dans une variable temporaire au lieu de l'injecter direct
            let nouveauHTML = "";
            
            if (messages.length === 0) {
                nouveauHTML = '<p class="waiting">Rien à modérer pour le moment.</p>';
            } else {
                messages.forEach(m => {
                    nouveauHTML += `
                        <div class="admin-card">
                            <div class="admin-card-content">
                                <span class="label">PENSÉE REÇUE :</span>
                                <p class="text">${m.texte}</p>
                            </div>
                            <div class="admin-actions">
                                <button class="btn btn-approve" onclick="moderer(${m.id}, 'valider')">OUI</button>
                                <button class="btn btn-reject" onclick="moderer(${m.id}, 'supprimer')">NON</button>
                            </div>
                        </div>`;
                });
            }

            // On compare : si le nouveau HTML est différent de l'ancien, on met à jour
            if (nouveauHTML !== dernierContenu) {
                container.innerHTML = nouveauHTML;
                dernierContenu = nouveauHTML; // On mémorise le nouvel état
            }
        });
}

function moderer(id, action) {
    fetch('/moderer', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({id: id, action: action})
    }).then(res => {
        if(res.ok) fetchMessages();
    });
}

setInterval(fetchMessages, 2000);
fetchMessages();