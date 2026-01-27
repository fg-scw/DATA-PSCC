#===============================================================================
# HACKATHON HDS - MAIN TERRAFORM CONFIGURATION
#===============================================================================

locals {
  team_cidrs = {
    for idx, team_key in keys(var.teams) : team_key => cidrsubnet(var.vpc_cidr, 8, idx)
  }
}

#-------------------------------------------------------------------------------
# Admin Project - Central storage
#-------------------------------------------------------------------------------
module "admin_project" {
  source = "./modules/admin-project"

  project_prefix      = var.project_prefix
  bucket_prefix       = var.bucket_prefix
  region              = var.region
  enable_access_logs  = var.enable_access_logs
  data_retention_days = var.data_retention_days
}

#-------------------------------------------------------------------------------
# Team Projects - One per participating team
#-------------------------------------------------------------------------------
module "team_projects" {
  for_each = var.teams
  source   = "./modules/team-project"

  project_prefix       = var.project_prefix
  team_name            = each.value.name
  team_members         = each.value.members
  region               = var.region
  zone                 = var.zone
  private_network_cidr = local.team_cidrs[each.key]

  bastion_instance_type   = var.bastion_instance_type
  bastion_image           = var.bastion_image
  bastion_ssh_port        = var.bastion_ssh_port
  gpu_instance_type       = var.gpu_instance_type
  gpu_image               = var.gpu_image
  gpu_root_volume_size_gb = var.gpu_root_volume_size_gb
  gpu_root_volume_iops    = var.gpu_root_volume_iops

  zone1_bucket_name           = module.admin_project.zone1_bucket_name
  zone1_bucket_endpoint       = module.admin_project.zone1_bucket_endpoint
  livrables_bucket_name       = module.admin_project.livrables_bucket_name
  livrables_bucket_endpoint   = module.admin_project.livrables_bucket_endpoint
  zone1_encryption_key_base64 = module.admin_project.zone1_encryption_key_base64

  challenge_end_date = var.challenge_end_date

  depends_on = [module.admin_project]
}

#-------------------------------------------------------------------------------
# IAM Global - Cross-project access management
#-------------------------------------------------------------------------------
module "iam_global" {
  source = "./modules/iam-global"

  organization_id = var.organization_id
  region          = var.region
  zone            = var.zone

  teams          = var.teams
  admins         = var.admins
  evaluators     = var.evaluators
  data_providers = var.data_providers

  admin_project_id = module.admin_project.project_id
  team_project_ids = {
    for key, team in var.teams : key => module.team_projects[key].project_id
  }

  # Pass bucket info for credentials bucket per team
  team_credentials_bucket_names = {
    for key, team in var.teams : key => module.team_projects[key].credentials_bucket_name
  }

  enable_console_access = var.enable_console_access
  challenge_end_date    = var.challenge_end_date
  dry_run               = var.dry_run

  depends_on = [module.admin_project, module.team_projects]
}

#-------------------------------------------------------------------------------
# Upload Portal - VM-based web interface for data providers (optional)
#-------------------------------------------------------------------------------
module "upload_portal" {
  count  = var.enable_upload_portal ? 1 : 0
  source = "./modules/upload-portal"

  project_prefix = var.project_prefix
  region         = var.region
  zone           = var.zone

  admin_project_id = module.admin_project.project_id
  instance_type    = var.upload_portal_instance_type

  zone1_bucket_name     = module.admin_project.zone1_bucket_name
  zone2_bucket_name     = module.admin_project.zone2_bucket_name
  livrables_bucket_name = module.admin_project.livrables_bucket_name

  zone1_encryption_key     = module.admin_project.zone1_encryption_key_base64
  zone2_encryption_key     = module.admin_project.zone2_encryption_key_base64
  livrables_encryption_key = module.admin_project.livrables_encryption_key_base64

  data_providers = var.data_providers

  scw_access_key = module.iam_global.admin_api_key.access_key
  scw_secret_key = module.iam_global.admin_api_key.secret_key

  depends_on = [module.admin_project, module.iam_global]
}

#-------------------------------------------------------------------------------
# Upload credentials to team buckets
#-------------------------------------------------------------------------------
resource "scaleway_object" "team_ssh_key" {
  for_each = var.teams

  bucket     = module.team_projects[each.key].credentials_bucket_name
  key        = "ssh_private_key.pem"
  file       = module.team_projects[each.key].ssh_private_key_path
  project_id = module.team_projects[each.key].project_id
  region     = var.region

  depends_on = [module.team_projects, module.iam_global]
}

resource "scaleway_object" "team_credentials_md" {
  for_each = var.teams

  bucket     = module.team_projects[each.key].credentials_bucket_name
  key        = "credentials.md"
  file       = "${path.root}/keys/${module.team_projects[each.key].team_slug}/credentials.md"
  project_id = module.team_projects[each.key].project_id
  region     = var.region

  depends_on = [module.team_projects, module.iam_global]
}

#-------------------------------------------------------------------------------
# Generate ACCESS.md
#-------------------------------------------------------------------------------
resource "local_file" "access_summary" {
  filename = "${path.root}/ACCESS.md"
  content  = <<-EOT
# Hackathon HDS - Access Information

Generated: ${timestamp()}
Mode: ${var.dry_run ? "DRY-RUN" : "PRODUCTION"}
Challenge End: ${var.challenge_end_date}

## Buckets

| Zone | Bucket | Endpoint |
|------|--------|----------|
| Zone 1 (Patients) | ${module.admin_project.zone1_bucket_name} | ${module.admin_project.zone1_bucket_endpoint} |
| Zone 2 (Evaluation) | ${module.admin_project.zone2_bucket_name} | ${module.admin_project.zone2_bucket_endpoint} |
| Livrables | ${module.admin_project.livrables_bucket_name} | ${module.admin_project.livrables_bucket_endpoint} |

## Teams

${join("\n", [for key, team in var.teams : "### ${team.name}\n- Project: ${module.team_projects[key].project_id}\n- Bastion: ${module.team_projects[key].bastion_public_ip}\n- GPU: ${module.team_projects[key].gpu_private_ip}\n- SSH: `${module.team_projects[key].ssh_connection_command}`\n- Credentials: `keys/${module.team_projects[key].team_slug}/`\n"])}

${var.enable_upload_portal ? "## Upload Portal\n\nURL: http://${module.upload_portal[0].public_ip}\nCredentials: See `keys/upload-portal/`\n" : ""}
EOT

  lifecycle {
    ignore_changes = [content]
  }
}
