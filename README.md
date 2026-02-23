# NSI "Présence" Projet - Words

Ce projet de NSI a pour but d'animer un évènement sur le thème de la Présence et sert de serveur et de point d'accès pour pouvoir s'y conecter et pouvoir ajouter un mot personnel sur le thème de la présence.

## Installation

Mettre le scipt d'installation en executable :

``` shell
chmod +x setup.sh
```

Pour installer le server et le point d'accès [RaspAP](https://github.com/RaspAP/raspap-webgui) :

``` shell
sudo ./setup.sh install
```

Pour configurer le server (port, mot de passe) :

``` shell
sudo ./setup.sh configure
```

## Utilisation

Les pages web du projet :

- page de gestion de `RaspAP` : `http://10.3.141.1/` (protégée par un mot de passe)

- page pour envoyer un mot : `http://10.3.141.1/nsi-presence-words/index.html` (qui est redirigée par défault comme portail captif de connexion)

- page pour le projecteur qui affiche les mots avec une animation : `http://10.3.141.1:<port>/projecteur`

- page admin de gestion : `http://10.3.141.1:<port>/admin` (protégée par un mot de passe)

Créer des [qr codes de connexion](qr_code/README.md)

NOTE : la configuration par défault est :

- port : `5000`, user : `admin`, mdp : `NSI`

## Désinstallation

Pour désinstaller complètement le server et le point d'accès :

``` shell
sudo ./setup.sh remove
```
