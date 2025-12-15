# ==============================================================================
# Variables Terraform
# ==============================================================================

variable "group_name" {
  description = "Nom du groupe pour les étudiants"
  type        = string
  default     = "students-inf-361"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]*$", var.group_name))
    error_message = "Le nom du groupe doit commencer par une lettre et ne contenir que des caractères alphanumériques, tirets et underscores."
  }
}

variable "auto_approve" {
  description = "Approuver automatiquement l'exécution sans confirmation"
  type        = bool
  default     = false
}

variable "log_level" {
  description = "Niveau de détail des logs"
  type        = string
  default     = "INFO"
  
  validation {
    condition     = contains(["DEBUG", "INFO", "WARN", "ERROR"], upper(var.log_level))
    error_message = "Le niveau de log doit être: DEBUG, INFO, WARN ou ERROR."
  }
}

variable "execute_ansible" {
  description = "Exécuter également le playbook Ansible"
  type        = bool
  default     = false
}

# Variables pour configuration cloud (optionnel)
variable "cloud_provider" {
  description = "Fournisseur cloud (pour extension future)"
  type        = string
  default     = "null"
  
  validation {
    condition     = contains(["null", "aws", "gcp", "azure", "digitalocean"], var.cloud_provider)
    error_message = "Provider supportés: null, aws, gcp, azure, digitalocean."
  }
}

variable "tags" {
  description = "Tags pour les ressources (optionnel)"
  type        = map(string)
  default = {
    Project     = "TP-Admin-Systeme"
    University  = "Université de Yaoundé I"
    Course      = "INF 3611"
    Environment = "Laboratoire"
    ManagedBy   = "Terraform"
  }
}

variable "disk_limit_gb" {
  description = "Limite disque par utilisateur (GB)"
  type        = number
  default     = 15
}