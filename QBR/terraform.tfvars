#===============================================================================
# HACKATHON HDS - CONFIGURATION
#===============================================================================

# Scaleway
scw_profile     = "hackathon-hds"
organization_id = "79a00b89-8d66-471f-888a-758f48a8e039"
region          = "fr-par"
zone            = "fr-par-2"
project_prefix  = "hackathon-hds"
bucket_prefix   = "final-pscc-data-2026"  # Must be globally unique

# Deployment
dry_run               = true   # false = send invitations
challenge_end_date    = "2026-02-26T23:59:59Z"
data_retention_days   = 1
enable_console_access = true

# Upload Portal (optional)
enable_upload_portal        = true
upload_portal_instance_type = "PLAY2-MICRO"

# Admins
admins = {
  name    = "PSCC"
  members = ["admin@pscc.fr"]
}

# Evaluators
evaluators = {
  name    = "IPP"
  members = ["eval@ipp.fr"]
}

# Data Providers
data_providers = {
  curie = {
    name    = "Institut Curie"
    members = ["data@curie.fr"]
  }
}

# Teams - Comment teams for partial deployment
teams = {
  team01 = {
    name    = "ATOS"
    members = ["participant@atos.net"]
  }
  
  # team02 = {
  #   name    = "THALES"
  #   members = ["participant@thales.com"]
  # }
}

# Infrastructure
gpu_instance_type       = "L40S-1-48G"
gpu_root_volume_size_gb = 125
gpu_root_volume_iops    = 5000
bastion_instance_type   = "PRO2-XS"
