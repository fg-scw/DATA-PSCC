#===============================================================================
# GENERAL CONFIGURATION
#===============================================================================

variable "organization_id" {
  description = "Scaleway Organization ID"
  type        = string
}

variable "region" {
  description = "Scaleway region"
  type        = string
  default     = "fr-par"
}

variable "zone" {
  description = "Scaleway zone"
  type        = string
  default     = "fr-par-2"
}

variable "project_prefix" {
  description = "Prefix for all project names"
  type        = string
  default     = "hackathon-hds"
}

variable "scw_profile" {
  description = "Nom du profil Scaleway à utiliser (défini dans ~/.config/scw/config.yaml). Si null, utilise les variables d'environnement ou le profil par défaut."
  type        = string
  default     = null
}

#===============================================================================
# DEPLOYMENT MODE
#===============================================================================

variable "dry_run" {
  description = "Mode dry-run : déploie l'infra sans créer les utilisateurs IAM (pas d'invitations envoyées)"
  type        = bool
  default     = false
}

#===============================================================================
# HACKATHON TIMING
#===============================================================================

variable "challenge_end_date" {
  description = "Date de fin du challenge (format: YYYY-MM-DDTHH:MM:SSZ) - Les accès seront révoqués après cette date"
  type        = string
  default     = "2025-02-26T23:59:59Z"
}

variable "data_retention_days" {
  description = "Durée de rétention des livrables en jours (Object Lock COMPLIANCE mode)"
  type        = number
  default     = 365
}

#===============================================================================
# TEAMS CONFIGURATION
#===============================================================================

variable "teams" {
  description = "Map des équipes participantes avec leurs membres"
  type = map(object({
    name    = string
    members = list(string) # Liste des emails
  }))
  default = {}
}

variable "enable_console_access" {
  description = "Activer l'accès à la console Scaleway pour les participants (sinon SSH uniquement)"
  type        = bool
  default     = false
}

#===============================================================================
# ADMINISTRATORS & DATA PROVIDERS
#===============================================================================

variable "admins" {
  description = "Administrateurs avec accès complet (PSCC)"
  type = object({
    name    = string
    members = list(string)
  })
  default = {
    name    = "PSCC"
    members = []
  }
}

variable "evaluators" {
  description = "Évaluateurs avec accès lecture Zone 2 et tous les GPU (IPP)"
  type = object({
    name    = string
    members = list(string)
  })
  default = {
    name    = "IPP"
    members = []
  }
}

variable "data_providers" {
  description = "Fournisseurs de données (établissements) avec accès RW sur Zone 1 et Zone 2"
  type = map(object({
    name    = string
    members = list(string)
  }))
  default = {}
}

#===============================================================================
# INFRASTRUCTURE SPECS
#===============================================================================

variable "gpu_instance_type" {
  description = "Type d'instance GPU pour les équipes"
  type        = string
  default     = "L40S-1-48G"
}

variable "gpu_root_volume_size_gb" {
  description = "Taille du volume root SBS pour les instances GPU (en GB)"
  type        = number
  default     = 200
}

variable "gpu_root_volume_iops" {
  description = "IOPS pour le volume SBS des instances GPU"
  type        = number
  default     = 15000
}

variable "gpu_image" {
  description = "Image pour les instances GPU"
  type        = string
  default     = "ubuntu_jammy_gpu_os_12"
}

variable "bastion_instance_type" {
  description = "Type d'instance pour le bastion/NAT"
  type        = string
  default     = "PRO2-XS"
}

variable "bastion_image" {
  description = "Image pour les instances bastion"
  type        = string
  default     = "ubuntu_jammy"
}

#===============================================================================
# STORAGE CONFIGURATION
#===============================================================================

variable "bucket_prefix" {
  description = "Prefix pour les noms de buckets (doit être unique globalement)"
  type        = string
}

variable "enable_access_logs" {
  description = "Activer les logs d'accès S3"
  type        = bool
  default     = true
}

#===============================================================================
# MONITORING
#===============================================================================

variable "enable_cockpit" {
  description = "Activer Cockpit pour le monitoring"
  type        = bool
  default     = true
}

#===============================================================================
# NETWORK CONFIGURATION
#===============================================================================

variable "vpc_cidr" {
  description = "CIDR de base pour les VPCs (sera subdivisé par équipe)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "bastion_ssh_port" {
  description = "Port SSH du bastion"
  type        = number
  default     = 22
}
