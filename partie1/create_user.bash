#!/bin/bash
# ==============================================================================
# TP Administration Systèmes - Script de création d'utilisateurs
# Université de Yaoundé I - Licence 3 Informatique - INF 3611
# ==============================================================================

#set -euo pipefail  # Mode strict : arrêt sur erreur

# ========================= CONSTANTES =========================
readonly SCRIPT_NAME="create_users.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly DEFAULT_USER_FILE="users.txt"
readonly DEFAULT_GROUP="students-inf-361"
readonly DEFAULT_SHELL="/bin/bash"
readonly LOG_DIR="/var/log/user_management"

# Limites système
readonly RAM_LIMIT_PERCENT=20
readonly DISK_LIMIT_GB=15
readonly DISK_LIMIT_KB=$((DISK_LIMIT_GB * 1024 * 1024))

# ========================= CONFIGURATION =========================
USER_FILE="${1:-$DEFAULT_USER_FILE}"
GROUP_NAME="${2:-$DEFAULT_GROUP}"
LOG_FILE="${LOG_DIR}/execution_$(date +%Y%m%d_%H%M%S).log"

# ========================= FONCTIONS UTILITAIRES =========================

# Initialisation du logging
init_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    echo "=== LOG SCRIPT - $(date) ===" > "$LOG_FILE"
}

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

check_prerequisites() {
    log_message "INFO" "Vérification des prérequis"
    
    # Vérification des privilèges root
    if [[ $EUID -ne 0 ]]; then
        log_message "ERROR" "Ce script doit être exécuté en tant que root"
        exit 1
    fi
    
    # Vérification du fichier d'entrée
    if [[ ! -f "$USER_FILE" ]]; then
        log_message "ERROR" "Fichier $USER_FILE introuvable"
        exit 1
    fi
    
    if [[ ! -s "$USER_FILE" ]]; then
        log_message "ERROR" "Fichier $USER_FILE vide"
        exit 1
    fi
    
    # Vérification des commandes nécessaires
    local required_cmds=("getent" "useradd" "usermod" "chpasswd" "chage")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_message "ERROR" "Commande $cmd non disponible"
            exit 1
        fi
    done
    
    log_message "SUCCESS" "Vérification des prérequis réussie"
}

create_group() {
    local group="$1"
    log_message "INFO" "Création du groupe: $group"
    
    if getent group "$group" > /dev/null 2>&1; then
        log_message "INFO" "Groupe $group existe déjà"
    else
        if groupadd "$group"; then
            log_message "SUCCESS" "Groupe $group créé"
        else
            log_message "ERROR" "Échec création groupe $group"
            exit 1
        fi
    fi
}

install_shell() {
    local shell="$1"
    
    # Si shell est bash, déjà installé
    [[ "$shell" == "/bin/bash" ]] && echo "$shell" && return 0
    
    # Vérifier si shell existe
    if grep -q "^$shell$" /etc/shells 2>/dev/null; then
       echo "$shell"
	 return 0
    fi
    
    # Déterminer le paquet à installer
    local package=""
    case "$shell" in
        "/bin/zsh"|"/usr/bin/zsh") package="zsh" ;;
        "/bin/fish"|"/usr/bin/fish") package="fish" ;;
        "/bin/dash"|"/usr/bin/dash") package="dash" ;;
        "/bin/ksh"|"/usr/bin/ksh") package="ksh" ;;
        "/bin/tcsh"|"/usr/bin/tcsh") package="tcsh" ;;
        *) 
            log_message "WARN" "Shell $shell non supporté, utilisation de $DEFAULT_SHELL"
            echo "$DEFAULT_SHELL"
            return 1
            ;;
    esac
    
    # Installation
    log_message "INFO" "Installation du shell: $shell (package: $package)"
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update >/dev/null 2>&1
        if apt-get install -y "$package" >/dev/null 2>&1; then
            # after installing, ensure the shell path is known in /etc/shells
            if ! grep -q "^$shell$" /etc/shells 2>/dev/null; then
                echo "$shell" >> /etc/shells
            fi
            echo "$shell"
            return 0
        fi
    fi
    
    log_message "ERROR" "Échec installation $shell"
    echo "$DEFAULT_SHELL"
    return 1
}

hash_password() {
    local password="$1"
    
    # Essayer mkpasswd
    if command -v mkpasswd >/dev/null 2>&1; then
        mkpasswd -m sha-512 "$password" && return 0
    fi
    
    # Essayer openssl
    if command -v openssl >/dev/null 2>&1; then
        openssl passwd -6 "$password" 2>/dev/null && return 0
    fi
    
    # Fallback Python
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import crypt; print(crypt.crypt('$password', crypt.mksalt(crypt.METHOD_SHA512)))" && return 0
    fi
    
    log_message "ERROR" "Aucune méthode de hachage disponible"
    exit 1
}

setup_welcome_message() {
    local user="$1"
    local home_dir="/home/$user"
    
    # Créer le message de bienvenue
    cat > "$home_dir/WELCOME.txt" << EOF
========================================================================
BIENVENUE SUR LE SERVEUR DE TP
========================================================================
Bonjour $user,

Votre compte a été créé avec succès.
Date: $(date '+%d/%m/%Y')
Serveur: $(hostname)

INFORMATIONS:
• Vous devez changer votre mot de passe à la première connexion
• Accès sudo activé (sauf commande 'su')
• Quota disque: ${DISK_LIMIT_GB} Go
• Limite RAM: ${RAM_LIMIT_PERCENT}%

Pour assistance: contacter $(hostname -d)
========================================================================
EOF
    
    chown "$user:$GROUP_NAME" "$home_dir/WELCOME.txt"
    chmod 644 "$home_dir/WELCOME.txt"
    
    # Ajouter à .bashrc
    if [[ -f "$home_dir/.bashrc" ]]; then
        if ! grep -q "WELCOME.txt" "$home_dir/.bashrc"; then
            echo -e "\n# Message de bienvenue" >> "$home_dir/.bashrc"
            echo "if [[ -f ~/WELCOME.txt && -z \"\$WELCOME_SHOWN\" ]]; then" >> "$home_dir/.bashrc"
            echo "    cat ~/WELCOME.txt" >> "$home_dir/.bashrc"
            echo "    export WELCOME_SHOWN=1" >> "$home_dir/.bashrc"
            echo "fi" >> "$home_dir/.bashrc"
        fi
    fi
    
    log_message "INFO" "Message de bienvenue configuré pour $user"
}

setup_quotas() {
    local user="$1"
    
    # Vérifier si quotas supportés
    if ! mount | grep -q "quota"; then
        log_message "WARN" "Quotas non activés sur le système"
        return 1
    fi
    
    # Définir quota
    if command -v setquota >/dev/null 2>&1; then
        setquota "$user" 0 "$DISK_LIMIT_KB" 0 0 /home 2>/dev/null && {
            log_message "SUCCESS" "Quota ${DISK_LIMIT_GB}Go défini pour $user"
            return 0
        }
    fi
    
    log_message "WARN" "Échec configuration quota pour $user"
    return 1
}

restrict_su_command() {
    local sudoers_file="/etc/sudoers.d/no-su-$GROUP_NAME"
    
    cat > "$sudoers_file" << EOF
# Empêcher l'utilisation de 'su' par le groupe $GROUP_NAME
%$GROUP_NAME ALL=(ALL) ALL, !/bin/su, !/usr/bin/su
EOF
    
    chmod 440 "$sudoers_file"
    
    # Valider syntaxe
    if visudo -c -f "$sudoers_file" >/dev/null 2>&1; then
        log_message "SUCCESS" "Restriction 'su' appliquée pour $GROUP_NAME"
	return 0
    else
        log_message "ERROR" "Syntaxe sudoers invalide"
        rm -f "$sudoers_file"
	return 0
    fi
}

create_user() {
    local username="$1"
    local password="$2"
    local full_name="$3"
    local phone="$4"
    local email="$5"
    local preferred_shell="$6"
    
    log_message "INFO" "Traitement utilisateur: $username"
    
    # Déterminer shell final
    local final_shell
    final_shell=$(install_shell "$preferred_shell")
    [[ $? -ne 0 ]] && final_shell="$DEFAULT_SHELL"
    
    # Champ GECOS
    local gecos="$full_name,$phone,$email"
    
    # Créer ou mettre à jour l'utilisateur
    if id "$username" >/dev/null 2>&1; then
        log_message "INFO" "Utilisateur $username existe déjà, mise à jour"
        usermod -s "$final_shell" -c "$gecos" "$username"
    else
        useradd -m -s "$final_shell" -c "$gecos" -g "$GROUP_NAME" "$username" || {
            log_message "ERROR" "Échec création $username"
            return 1
        }
        log_message "SUCCESS" "Utilisateur $username créé"
    fi
    
    # Définir mot de passe haché
    local hashed_pass
    hashed_pass=$(hash_password "$password")
    echo "$username:$hashed_pass" | chpasswd -e
    
    # Forcer changement mot de passe
    chage -d 0 "$username"
    
    # Ajouter au groupe sudo
    usermod -aG sudo "$username"
    
    # Configurer message de bienvenue
    setup_welcome_message "$username"
    
    # Configurer quotas
    setup_quotas "$username"
    
    log_message "SUCCESS" "Configuration complète pour $username"
    return 0
}

# ========================= MAIN =========================
main() {
    init_logging
    log_message "INFO" "Démarrage script v$SCRIPT_VERSION"
    log_message "INFO" "Fichier: $USER_FILE, Groupe: $GROUP_NAME"
    
    check_prerequisites
    create_group "$GROUP_NAME"
    restrict_su_command
    
    # Statistiques
    local total=0 success=0 fail=0
    
    # Lecture du fichier
    while IFS=';' read -r username password full_name phone email preferred_shell || [[ -n "$username" ]]; do

	 # Ignorer lignes vides et commentaires
        [[ -z "$username" || "$username" =~ ^[[:space:]]*# ]] && continue
        # Nettoyer
        username=$(echo "$username" | xargs)
        password=$(echo "$password" | xargs)
        full_name=$(echo "$full_name" | xargs)
        phone=$(echo "$phone" | xargs)
        email=$(echo "$email" | xargs)
        preferred_shell=$(echo "$preferred_shell" | xargs)
       
        [[ -z "$preferred_shell" ]] && preferred_shell="$DEFAULT_SHELL"
        
        ((total++))
        log_message "INFO" "--- Traitement #$total: $username ---"
        
        if create_user "$username" "$password" "$full_name" "$phone" "$email" "$preferred_shell"; then
            ((success++))
        else
            ((fail++))
        fi
        
        echo "" >> "$LOG_FILE"
        
    done < "$USER_FILE"
    
    # Résumé
    log_message "INFO" "=== RÉSUMÉ EXÉCUTION ==="
    log_message "INFO" "Total: $total | Succès: $success | Échecs: $fail"
    log_message "INFO" "Log détaillé: $LOG_FILE"
    
    if [[ $fail -eq 0 ]]; then
        log_message "SUCCESS" "Script terminé avec succès"
        exit 0
    else
        log_message "ERROR" "Script terminé avec $fail échec(s)"
        exit 1
    fi
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
