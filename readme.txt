TP Administration Systèmes et Réseaux - INF 3611

Description
-----------
Automatisation de la création d'utilisateurs et de la configuration associée pour le cours INF 3611. Ce dépôt contient :
- `partie1/` : script Bash pour créer des utilisateurs localement.
- `partie2/` : playbook Ansible pour créer des utilisateurs sur des hôtes distants.
- `partie3/` : configuration Terraform qui peut déclencher l'exécution du script et du playbook (avec précautions).

Auteur: SOFO DIDIER BRASSY

Prérequis
---------
- Système : Linux (Ubuntu 20.04+ recommandé)
- Outils : `bash`, `python3`, `ansible` (2.10+), `terraform` (1.0+)
- Accès SSH aux hôtes distants (clé SSH recommandée) et un utilisateur avec `sudo`.

Partie 1 : Script Bash (local)
-----------------------------
Fichier principal : `partie1/create_user.bash`
- Crée le groupe (par défaut `students-inf-361`) et les comptes listés dans `partie1/users.txt`.
- Hache les mots de passe (SHA-512), force changement à la première connexion, ajoute message de bienvenue, configure quotas si possible.

Utilisation (local, requiert root) :
```bash
sudo chmod +x partie1/create_user.bash
sudo partie1/create_user.bash partie1/users.txt students-inf-361
```

ATTENTION : ce script modifie le système local (création d'utilisateurs). Ne l'exécutez pas directement sur votre poste de travail si vous ne souhaitez pas créer d'utilisateurs locaux.

Partie 2 : Ansible — fonctionnement et exécution (recommandé pour VPS)
-------------------------------------------------------------------
But
----
Créer et configurer les comptes utilisateurs sur les serveurs distants via SSH. Ansible applique les mêmes règles que le script Bash mais à distance, de manière idempotente.

Contenu important
- `partie2/create_user.yml` : playbook principal.
- `partie2/users.yml` : données des utilisateurs (liste `students` et `admin_users`).
- `partie2/inventory.ini` : inventaire. Modifiez `ansible_host`, `ansible_user`, `ansible_ssh_private_key_file` ou `ansible_ssh_pass` selon votre configuration.
- `partie2/group_vars/all.yml` : variables globales (inclut SMTP). **Chiffrez** si nécessaire avec `ansible-vault`.
- `partie2/tasks/send_emails.yml` : envoie email via `community.general.smtp`.
- `partie2/roles/student_users/...` : tâches pour créer utilisateur et configurer quotas.

Installer dépendances
--------------------
```bash
ansible-galaxy collection install -r partie2/requirements.yml
```

Configuration recommandée pour votre VPS
---------------------------------------
- Exemple d'entrée `partie2/inventory.ini` :
    ```ini
    [students_servers]
    vps_tp ansible_host=172.20.0.30 ansible_user=lepro ansible_ssh_private_key_file=~/.ssh/id_rsa
    [students_servers:vars]
    ansible_python_interpreter=/usr/bin/python3
    ```
- Si vous utilisez mot de passe SSH, préférez `--ask-pass` plutôt que laisser le mot de passe en clair.
- Pour `become` (sudo) : utilisez `--ask-become-pass` ou stockez `ansible_become_pass` chiffré dans vault.

SMTP (envoi d'e-mails)
---------------------
- Variables dans `partie2/group_vars/all.yml` : `smtp_server`, `smtp_port`, `smtp_username`, `smtp_password`, `smtp_use_tls`.
- Pour Gmail : utilisez un App Password si 2FA activé. Sinon Gmail peut bloquer la connexion.
- Stockez `smtp_password` dans `ansible-vault` :
    ```bash
    ansible-vault encrypt partie2/group_vars/all.yml
    ```

Commandes pratiques
-------------------
- Ping Ansible (test connexion) :
    ```bash
    ansible -i partie2/inventory.ini students_servers -m ping
    ```
- Syntax check :
    ```bash
    ansible-playbook -i partie2/inventory.ini partie2/create_user.yml --syntax-check
    ```
- Dry run (simulation) :
    ```bash
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i partie2/inventory.ini partie2/create_user.yml --check --diff
    ```
- Exécution réelle :
    ```bash
    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i partie2/inventory.ini partie2/create_user.yml
    ```
- Si sudo demande mot de passe :
    ```bash
    ansible-playbook -i partie2/inventory.ini partie2/create_user.yml --ask-become-pass
    ```

Sécurité
--------
- Toujours chiffrer les secrets avec `ansible-vault`.
- Préférez clés SSH et comptes de service restreints (ou NOPASSWD sudo en environnement de test).

Partie 3 : Terraform — explication et précautions
------------------------------------------------
Que fait `partie3` ?
- Le `main.tf` fourni exécute le script Bash via un `null_resource` + `local-exec`, puis lance le playbook Ansible localement. Cela signifie :
    - Le script Bash est exécuté sur la machine où vous lancez `terraform apply` (machine de contrôle).
    - Ansible est appelé localement et se connectera aux hôtes distants selon l'inventaire.

Pourquoi c'est important
------------------------
- Si vous lancez Terraform depuis votre poste, le script crée des utilisateurs localement (effet observé). Pour cibler le VPS, deux options :
    1) Utiliser Ansible directement depuis la machine de contrôle (recommandé). Exemple :
         ```bash
         ansible-playbook -i partie2/inventory.ini partie2/create_user.yml
         ```
    2) Adapter Terraform pour exécuter la commande à distance via `remote-exec` et config `connection` SSH (plus de complexité et gestion des clés/mots de passe).

Recommandation
--------------
- N'utilisez pas `terraform apply` en root sur votre poste de travail si vous ne voulez pas modifier votre système local.
- Si vous voulez que je modifie `main.tf` pour rendre l'exécution locale optionnelle ou pour utiliser `remote-exec`, je peux le faire.

Nettoyage local (si nécessaire)
------------------------------
Si Terraform a exécuté le script localement et que vous souhaitez annuler :
```bash
sudo userdel -r etudiant1 etudiant2 etudiant4 etudiant5 admin
sudo rm -rf /var/log/user_management
```

Checklist finale avant exécution sur le VPS
-----------------------------------------
1. Mettre à jour `partie2/inventory.ini` pour `172.20.0.30` et `lepro`.
2. Ajouter la clé privée SSH à `~/.ssh/` et référencer-la (`ansible_ssh_private_key_file`).
3. Chiffrer `group_vars/all.yml` si nécessaire.
4. Installer la collection : `ansible-galaxy collection install -r partie2/requirements.yml`.
5. Tester la connexion puis exécuter en `--check`, enfin exécuter sans `--check`.

Souhaitez-vous que j'ajoute des exemples exacts avec `172.20.0.30` et l'utilisateur `lepro`, ou que je rende l'exécution Terraform conditionnelle ? Indiquez "exemples" ou "conditionnelle".


