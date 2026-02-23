# NSI "Présence" Projet - Words

Ce projet de NSI a pour but d'animer un évènement sur le thème de la Présence et sert de serveur et de point d'accès pour pouvoir s'y conecter et pouvoir ajouter un mot personnel sur le thème de la présence.

## Installation

Pour installer le server et `RaspAP`:

``` shell
sudo bash setup.sh install
```

Ou pour installer juste le point d'accès :

``` shell
bash raspap.sh install
```

## Utilisation

Les pages web du projet :

- page de gestion de `RaspAP` : `http://10.3.141.1/` (protégée par un mot de passe)

- page pour envoyer un mot : `http://10.3.141.1/nsi-presence-words/index.html` (qui est redirigée par défault comme portail captif de connexion)

- page pour le projecteur qui affiche les mots avec une animation : `http://10.3.141.1/nsi-presence-words/projecteur.html`

- page admin de gestion : `http://10.3.141.1/nsi-presence-words/admin.html` (protégée par un mot de passe)

Créer des [qr codes de connexion](qr_code/README.md)

## Désinstallation

Pour désinstaller complètement le server et le point d'accès :

``` shell
sudo bash setup.sh remove
```
