# ==============================================================================
# TP Administration Systèmes - Terraform Configuration
# Université de Yaoundé I - Licence 3 Informatique - INF 3611
# ==============================================================================

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    # Provider pour exécution locale (pas de création de VPS)
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
    
    # Optionnel: Pour création de VPS dans le cloud
    # aws = {
    #   source  = "hashicorp/aws"
    #   version = "~> 4.0"
    # }
  }
}

# ========================= RESSOURCES PRINCIPALES =========================

# Exécution du script Bash
resource "null_resource" "execute_bash_script" {
  # Déclencheurs: re-exécuter si ces fichiers changent
  triggers = {
    script_version  = "1.0.0"
    script_hash     = filemd5("${path.module}/../partie1/create_user.bash")
    users_hash      = filemd5("${path.module}/../partie1/users.txt")
    timestamp       = timestamp()
  }
  
  # Provisioner: Exécution locale du script
  provisioner "local-exec" {
    command = <<-EOT
      echo " Démarrage de l'exécution Terraform"
      echo " Date: $(date)"
      echo "========================================"
      
      # Rendre le script exécutable
      chmod +x ${path.module}/../partie1/create_user.bash
      
      # Exécuter le script
      cd ${path.module}/../partie1
      ./create_user.bash users.txt ${var.group_name}
      
      # Vérifier le code de retour
      if [ $? -eq 0 ]; then
        echo " Script exécuté avec succès"
      else
        echo " Échec de l'exécution du script"
        exit 1
      fi
    EOT
    
    interpreter = ["/bin/bash", "-c"]
    
    environment = {
      TF_EXECUTION = "true"
      LOG_LEVEL    = "INFO"
    }
  }
  
  # Exécution du playbook Ansible (optionnel)
  provisioner "local-exec" {
    command = <<-EOT
      echo " Exécution du playbook Ansible..."
      
      cd ${path.module}/../partie2

      # Vérifier la syntaxe
      ansible-playbook create_user.yml --syntax-check

      # Exécuter en mode check d'abord
      ansible-playbook -i inventory.ini create_user.yml --check

      # Exécuter pour de vrai
      ansible-playbook -i inventory.ini create_user.yml
      
      echo " Playbook Ansible exécuté"
    EOT
    
    when = create
    interpreter = ["/bin/bash", "-c"]
  }
  
  # Nettoyage (optionnel - pour destroy)
  provisioner "local-exec" {
    command = <<-EOT
      echo " Nettoyage des ressources..."
      echo "Cette opération ne supprime pas les utilisateurs créés."
      echo "Pour supprimer les utilisateurs, exécutez manuellement:"
      echo "  sudo userdel -r etudiant1"
      echo "  sudo userdel -r etudiant2"
      echo "  ..."
    EOT
    
    when = destroy
    interpreter = ["/bin/bash", "-c"]
  }
}

# Optionnel: Création d'un fichier de rapport
resource "local_file" "execution_report" {
  filename = "${path.module}/execution_report_${timestamp()}.txt"
  content  = <<-EOT
    Rapport d'exécution Terraform
    =============================
    Projet: TP Administration Systèmes
    Date: ${timestamp()}
    Script: ${path.module}/../partie1/create_user.bash
    Groupe: ${var.group_name}
    Fichier utilisateurs: ${path.module}/../partie1/users.txt

    Résultat: Script exécuté via Terraform (exécution locale)
    Prochaine exécution: terraform apply

    Notes:
    - Les utilisateurs ont été créés/traités par le script indiqué
    - Le message de bienvenue est configuré
    - La commande 'su' peut être restreinte pour le groupe
  EOT
  
  depends_on = [null_resource.execute_bash_script]
}

# ========================= SORTIES =========================

output "execution_status" {
  value       = "Script exécuté avec succès le ${timestamp()}"
  description = "Statut de l'exécution"
}

output "resources_created" {
  value = {
    bash_script  = "create_users.bash"
    user_file    = "users.txt"
    group_name   = var.group_name
    timestamp    = timestamp()
  }
  description = "Ressources créées/gérées"
}

output "next_steps" {
  value = <<-EOT
     Prochaines étapes:
    1. Vérifier les utilisateurs créés: getent group ${var.group_name}
    2. Tester la connexion d'un utilisateur
    3. Vérifier les quotas: quota -s
    4. Consulter les logs: tail -f /var/log/user_management/*
    
    Pour détruire (ne supprime pas les utilisateurs):
    terraform destroy
  EOT
  description = "Instructions post-exécution"

}
