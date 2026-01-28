#===============================================================================
# OUTPUTS
#===============================================================================

output "admin_project_id" {
  description = "Admin project ID"
  value       = module.admin_project.project_id
}

output "zone1_bucket" {
  description = "Zone 1 bucket"
  value = {
    name     = module.admin_project.zone1_bucket_name
    endpoint = module.admin_project.zone1_bucket_endpoint
  }
}

output "zone2_bucket" {
  description = "Zone 2 bucket"
  value = {
    name     = module.admin_project.zone2_bucket_name
    endpoint = module.admin_project.zone2_bucket_endpoint
  }
}

output "livrables_bucket" {
  description = "Livrables bucket"
  value = {
    name     = module.admin_project.livrables_bucket_name
    endpoint = module.admin_project.livrables_bucket_endpoint
  }
}

output "team_access" {
  description = "Team access information"
  value = {
    for key, team in var.teams : team.name => {
      project_id          = module.team_projects[key].project_id
      bastion_ip          = module.team_projects[key].bastion_public_ip
      gpu_private_ip      = module.team_projects[key].gpu_private_ip
      ssh_command         = module.team_projects[key].ssh_connection_command
      ssh_command_alt     = module.team_projects[key].ssh_connection_command_alt
      credentials_path    = "keys/${module.team_projects[key].team_slug}/"
      credentials_bucket  = module.team_projects[key].credentials_bucket_name
    }
  }
}

output "team_ssh_commands" {
  description = "SSH commands for each team"
  value = [for key, team in var.teams : "# ${team.name}\n${module.team_projects[key].ssh_connection_command}"]
}

output "encryption_keys" {
  description = "SSE-C encryption keys (base64)"
  value = {
    zone1     = module.admin_project.zone1_encryption_key_base64
    zone2     = module.admin_project.zone2_encryption_key_base64
    livrables = module.admin_project.livrables_encryption_key_base64
  }
  sensitive = true
}

output "upload_portal" {
  description = "Upload portal information"
  value = var.enable_upload_portal ? {
    enabled     = true
    public_ip   = module.upload_portal[0].public_ip
    url         = "http://${module.upload_portal[0].public_ip}"
    ssh_command = module.upload_portal[0].ssh_command
  } : {
    enabled     = false
    public_ip   = null
    url         = null
    ssh_command = null
  }
}

output "dry_run_mode" {
  value = var.dry_run
}

output "challenge_end_date" {
  value = var.challenge_end_date
}

output "summary" {
  value = <<-EOT

========================================================================
                HACKATHON HDS - DEPLOYMENT COMPLETE
========================================================================

Mode: ${var.dry_run ? "DRY-RUN (no invitations sent)" : "PRODUCTION"}
Teams: ${length(var.teams)}
Challenge ends: ${var.challenge_end_date}
${var.enable_upload_portal ? "\nUpload Portal:\n  URL: http://${module.upload_portal[0].public_ip}\n  SSH: ${module.upload_portal[0].ssh_command}" : ""}

Buckets:
  - Zone 1: ${module.admin_project.zone1_bucket_name}
  - Zone 2: ${module.admin_project.zone2_bucket_name}
  - Livrables: ${module.admin_project.livrables_bucket_name}

Team SSH Access:
${join("\n", [for key, team in var.teams : "  ${team.name}: ${module.team_projects[key].ssh_connection_command}"])}

Documentation: ACCESS.md
========================================================================
EOT
}
