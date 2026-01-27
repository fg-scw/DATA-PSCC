#===============================================================================
# OUTPUTS
#===============================================================================

#-------------------------------------------------------------------------------
# Admin Project Outputs
#-------------------------------------------------------------------------------
output "admin_project_id" {
  description = "Admin project ID"
  value       = module.admin_project.project_id
}

output "zone1_bucket" {
  description = "Zone 1 bucket information"
  value = {
    name     = module.admin_project.zone1_bucket_name
    endpoint = module.admin_project.zone1_bucket_endpoint
  }
}

output "zone2_bucket" {
  description = "Zone 2 bucket information"
  value = {
    name     = module.admin_project.zone2_bucket_name
    endpoint = module.admin_project.zone2_bucket_endpoint
  }
}

output "livrables_bucket" {
  description = "Livrables bucket information"
  value = {
    name     = module.admin_project.livrables_bucket_name
    endpoint = module.admin_project.livrables_bucket_endpoint
  }
}

#-------------------------------------------------------------------------------
# Team Access Outputs
#-------------------------------------------------------------------------------
output "team_access" {
  description = "SSH access commands for each team"
  value = {
    for key, team in var.teams : team.name => {
      project_id       = module.team_projects[key].project_id
      bastion_ip       = module.team_projects[key].bastion_public_ip
      gpu_private_ip   = module.team_projects[key].gpu_private_ip
      ssh_command      = module.team_projects[key].ssh_connection_command
      credentials_path = "keys/${module.team_projects[key].team_slug}/"
    }
  }
}

output "team_ssh_commands" {
  description = "Quick SSH commands for each team"
  value = [
    for key, team in var.teams :
    "# ${team.name}\n${module.team_projects[key].ssh_connection_command}"
  ]
}

#-------------------------------------------------------------------------------
# Encryption Keys (sensitive)
#-------------------------------------------------------------------------------
output "encryption_keys" {
  description = "SSE-C encryption keys (base64)"
  value = {
    zone1     = module.admin_project.zone1_encryption_key_base64
    zone2     = module.admin_project.zone2_encryption_key_base64
    livrables = module.admin_project.livrables_encryption_key_base64
  }
  sensitive = true
}

#-------------------------------------------------------------------------------
# IAM Information
#-------------------------------------------------------------------------------
output "users_created" {
  description = "List of IAM users created (empty in dry_run mode)"
  value       = module.iam_global.users_created
}

output "dry_run_mode" {
  description = "Whether deployment is in dry_run mode"
  value       = var.dry_run
}

output "challenge_end_date" {
  description = "Date when participant access expires"
  value       = var.challenge_end_date
}

#-------------------------------------------------------------------------------
# Summary
#-------------------------------------------------------------------------------
output "summary" {
  description = "Deployment summary"
  value       = <<-EOT
    
    ========================================================================
                    HACKATHON HDS - DEPLOYMENT COMPLETE
    ========================================================================
    
    Mode: ${var.dry_run ? "DRY-RUN (no invitations sent)" : "PRODUCTION"}
    Teams deployed: ${length(var.teams)}
    Challenge ends: ${var.challenge_end_date}
    Console access: ${var.enable_console_access ? "ENABLED" : "DISABLED"}
    
    Buckets:
      - Zone 1 (patients): ${module.admin_project.zone1_bucket_name}
      - Zone 2 (evaluation): ${module.admin_project.zone2_bucket_name}
      - Livrables: ${module.admin_project.livrables_bucket_name}
    
    Next steps:
      1. Distribute credentials from keys/ to each team
      2. Upload patient data: ./scripts/upload-to-zone1.sh <data_dir>
      3. Upload evaluation data: ./scripts/upload-to-zone2.sh <data_dir>
    ${var.dry_run ? "\n    ⚠️  DRY-RUN: Set dry_run=false and re-apply for production" : ""}
    
    Documentation: ACCESS.md
    ========================================================================
  EOT
}
