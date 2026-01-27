#===============================================================================
# HACKATHON HDS - CONFIGURATION EXAMPLE
#===============================================================================
# Copiez ce fichier en terraform.tfvars et adaptez les valeurs
#===============================================================================

#-------------------------------------------------------------------------------
# Configuration Scaleway
#-------------------------------------------------------------------------------
# Utilisez un profil dédié pour isoler ce déploiement de vos autres projets
# Le profil doit être défini dans ~/.config/scw/config.yaml
scw_profile = "hackathon-hds"

organization_id = "79a00b89-8d66-471f-888a-758f48a8e039"
region          = "fr-par"
zone            = "fr-par-2"
project_prefix  = "hackathon-hds"
bucket_prefix   = "pscc-hackathon-2026" # Doit être unique globalement

#-------------------------------------------------------------------------------
# Mode de déploiement
#-------------------------------------------------------------------------------
# dry_run = true  -> Déploie l'infra SANS créer les utilisateurs (pas d'invitations)
# dry_run = false -> Déploiement complet avec invitations par email
dry_run = true  # Mettre à false pour le déploiement final

#-------------------------------------------------------------------------------
# Dates du challenge
#-------------------------------------------------------------------------------
challenge_end_date  = "2026-02-26T23:59:59Z"
data_retention_days = 365

#-------------------------------------------------------------------------------
# Accès console Scaleway pour les participants
#-------------------------------------------------------------------------------
enable_console_access = true # false = SSH uniquement

#-------------------------------------------------------------------------------
# Monitoring
#-------------------------------------------------------------------------------
enable_cockpit     = true
enable_access_logs = true

#-------------------------------------------------------------------------------
# Administrateurs (PSCC - Full Access)
#-------------------------------------------------------------------------------
admins = {
  name = "PSCC"
  members = [
    "admin1@pscc.fr",
    "admin2@pscc.fr",
  ]
}

#-------------------------------------------------------------------------------
# Évaluateurs (IPP - Read Only Zone 2 + accès GPU participants)
#-------------------------------------------------------------------------------
evaluators = {
  name = "IPP"
  members = [
    "evaluateur@ipp.fr",
  ]
}

#-------------------------------------------------------------------------------
# Fournisseurs de données (Établissements - RW Zone 1 & 2)
#-------------------------------------------------------------------------------
data_providers = {
  curie = {
    name = "Institut Curie"
    members = [
      "chercheur1@curie.fr",
      "chercheur2@curie.fr",
      "chercheur3@curie.fr",
    ]
  }
  igr = {
    name = "Institut Gustave Roussy"
    members = [
      "chercheur@gustaveroussy.fr",
    ]
  }
}

#-------------------------------------------------------------------------------
# Équipes participantes
#-------------------------------------------------------------------------------
teams = {
  team01 = {
    name = "THALES SERVICES NUMERIQUES"
    members = [
      "participant1@thalesgroup.com",
    ]
  }
  team02 = {
    name = "COEXYA"
    members = [
      "participant@coexya.eu",
    ]
  }
  team03 = {
    name = "SOPRA STERIA"
    members = [
      "participant@soprasteria.com",
    ]
  }
  team04 = {
    name = "OCTO"
    members = [
      "participant@octo.com",
    ]
  }
  team05 = {
    name = "USE & SHARE"
    members = [
      "participant@useshare.fr",
    ]
  }
  team06 = {
    name = "CLARANET"
    members = [
      "participant@claranet.fr",
    ]
  }
  team07 = {
    name = "ATOS"
    members = [
      "participant@atos.net",
    ]
  }
  team08 = {
    name = "EURANOVA"
    members = [
      "participant@euranova.eu",
    ]
  }
}

#-------------------------------------------------------------------------------
# Configuration infrastructure (optionnel - valeurs par défaut recommandées)
#-------------------------------------------------------------------------------
gpu_instance_type       = "L40S-1-48G"
gpu_root_volume_size_gb = 125
gpu_root_volume_iops    = 5000
gpu_image               = "ubuntu_jammy_gpu_os_12"
# bastion_instance_type   = "PRO2-XS"
# bastion_image           = "ubuntu_jammy"
# vpc_cidr                = "10.0.0.0/16"
# bastion_ssh_port        = 22
