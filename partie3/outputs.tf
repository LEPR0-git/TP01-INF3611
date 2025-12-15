# ==============================================================================
# Outputs Terraform
# ==============================================================================

output "execution_complete" {
  value       = true
  description = "Indicateur d'exécution complète"
}

output "generated_files" {
  value = [
    local_file.execution_report.filename
  ]
  description = "Fichiers générés par Terraform"
}

output "verification_commands" {
  value = <<-EOT
    Commandes de vérification:
    
    # Vérifier le groupe
    getent group ${var.group_name}
    
    # Vérifier les utilisateurs créés
    members ${var.group_name}
    
    # Vérifier les quotas
    repquota -a
    
    # Vérifier les logs
    ls -la /var/log/user_management/
    tail -20 $(ls -t /var/log/user_management/*.log | head -1)
    
    # Tester un utilisateur
    sudo su - etudiant1 -c "id && pwd"
  EOT
  description = "Commandes pour vérifier l'installation"
}

output "security_notes" {
  value = <<-EOT
    Notes de sécurité:
    
    1. Les mots de passe initiaux sont dans users.txt
    2. Changement forcé à la première connexion
    3. Commande 'su' restreinte pour le groupe
    4. Quotas disque activés (${var.disk_limit_gb} Go)
    5. Logs disponibles dans /var/log/user_management/
    
    Actions recommandées:
    - Changer les mots de passe administrateur
    - Configurer l'authentification SSH par clés
    - Mettre à jour les paquets système
    - Configurer un firewall
  EOT
  description = "Notes importantes sur la sécurité"
}