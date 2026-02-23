const form = document.getElementById('presence-form');
const textarea = document.getElementById('message');
const counter = document.getElementById('char-counter');
const successScreen = document.getElementById('success-screen');

// Configuration de la limite
const MAX_CHARS = 25;

// Gestion du compteur de caractères en temps réel
textarea.addEventListener('input', () => {
    const remaining = MAX_CHARS - textarea.value.length;
    
    // Met à jour le texte du compteur
    counter.innerText = `${remaining} caractères restants`;
    
    // Change la couleur si on descend à 5 ou moins
    if (remaining <= 5) {
        counter.style.color = "#e63946";
        counter.style.fontWeight = "bold";
    } else {
        counter.style.color = "#666";
        counter.style.fontWeight = "normal";
    }
});

// Gestion de l'envoi du formulaire (AJAX)
form.addEventListener('submit', function(e) {
    e.preventDefault(); // Empêche le rechargement de la page

    const formData = new FormData(form);

    // Envoi des données au serveur Python
    fetch('/envoyer', {
        method: 'POST',
        body: formData
    })
    .then(response => {
        if (response.ok) {
            // Affiche l'écran de succès
            form.classList.add('hidden');
            successScreen.classList.remove('hidden');

            // Attend 5 secondes (temps de l'animation CSS) puis réinitialise
            setTimeout(() => {
                // Cache l'écran de succès et réaffiche le formulaire
                successScreen.classList.add('hidden');
                form.classList.remove('hidden');
                
                // Réinitialise le champ et le compteur
                form.reset();
                counter.innerText = `${MAX_CHARS} caractères restants`;
                counter.style.color = "#666";
                counter.style.fontWeight = "normal";
            }, 5000);
        } else {
            alert("Erreur lors de l'envoi. Veuillez réessayer.");
        }
    })
    .catch(err => {
        console.error("Erreur réseau :", err);
    });
});
