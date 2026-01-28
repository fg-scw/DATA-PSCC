output "team_api_keys" {
  value = {
    for key, team in var.teams : key => {
      access_key = scaleway_iam_api_key.team[key].access_key
      secret_key = scaleway_iam_api_key.team[key].secret_key
    }
  }
  sensitive = true
}

output "admin_api_key" {
  value = {
    access_key = scaleway_iam_api_key.admin.access_key
    secret_key = scaleway_iam_api_key.admin.secret_key
  }
  sensitive = true
}

output "evaluators_api_key" {
  value = {
    access_key = scaleway_iam_api_key.evaluators.access_key
    secret_key = scaleway_iam_api_key.evaluators.secret_key
  }
  sensitive = true
}

output "users_created" {
  value = var.enable_console_access && !var.dry_run ? [for u in scaleway_iam_user.all : u.email] : []
}

output "dry_run_mode" {
  value = var.dry_run
}
