output "team_api_keys" {
  description = "API keys for each team"
  value = {
    for key, team in var.teams : key => {
      access_key = scaleway_iam_api_key.team[key].access_key
      secret_key = scaleway_iam_api_key.team[key].secret_key
      expires_at = var.challenge_end_date
    }
  }
  sensitive = true
}

output "admin_api_key" {
  description = "Admin API key"
  value = {
    access_key = scaleway_iam_api_key.admin.access_key
    secret_key = scaleway_iam_api_key.admin.secret_key
  }
  sensitive = true
}

output "data_provider_api_keys" {
  description = "API keys for data providers"
  value = {
    for key, provider in var.data_providers : key => {
      access_key = scaleway_iam_api_key.data_providers[key].access_key
      secret_key = scaleway_iam_api_key.data_providers[key].secret_key
      expires_at = var.challenge_end_date
    }
  }
  sensitive = true
}

output "team_group_ids" {
  description = "IAM group IDs for each team"
  value = {
    for key, team in var.teams : key => scaleway_iam_group.team[key].id
  }
}

output "users_created" {
  description = "List of users created (empty in dry_run mode)"
  value       = var.enable_console_access && !var.dry_run ? [for user in scaleway_iam_user.all : user.email] : []
}

output "dry_run_mode" {
  description = "Whether dry_run mode is enabled"
  value       = var.dry_run
}
