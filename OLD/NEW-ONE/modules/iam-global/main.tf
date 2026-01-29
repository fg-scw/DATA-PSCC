#===============================================================================
# IAM GLOBAL MODULE - FIXED VERSION
# Added: Separate S3 API key per team with admin project access
#===============================================================================

locals {
  clean_team_slug = {
    for k, v in var.teams : k => replace(lower(replace(replace(v.name, "&", "and"), " ", "-")), "/[^a-z0-9\\-]/", "")
  }

  clean_provider_slug = {
    for k, v in var.data_providers : k => replace(lower(replace(replace(v.name, "&", "and"), " ", "-")), "/[^a-z0-9\\-]/", "")
  }

  all_emails = distinct(concat(
    flatten([for t in var.teams : t.members]),
    var.admins.members,
    var.evaluators.members,
    flatten([for p in var.data_providers : p.members])
  ))
}

#-------------------------------------------------------------------------------
# IAM Users (skipped in dry_run mode)
#-------------------------------------------------------------------------------
resource "scaleway_iam_user" "all" {
  for_each        = var.enable_console_access && !var.dry_run ? toset(local.all_emails) : toset([])
  email           = each.value
  username        = replace(split("@", each.value)[0], ".", "-")
  organization_id = var.organization_id
}

#-------------------------------------------------------------------------------
# IAM Applications
#-------------------------------------------------------------------------------
resource "scaleway_iam_application" "team" {
  for_each        = var.teams
  name            = "app-hackathon-${local.clean_team_slug[each.key]}"
  organization_id = var.organization_id
  description     = "API access for team ${each.value.name}"
}

# NEW: Separate application for S3 access (needs admin project as default)
resource "scaleway_iam_application" "team_s3" {
  for_each        = var.teams
  name            = "app-hackathon-${local.clean_team_slug[each.key]}-s3"
  organization_id = var.organization_id
  description     = "S3 access for team ${each.value.name} (Zone1 read, Livrables write)"
}

resource "scaleway_iam_application" "admin" {
  name            = "app-hackathon-admin"
  organization_id = var.organization_id
  description     = "API access for administrators"
}

resource "scaleway_iam_application" "data_providers" {
  for_each        = var.data_providers
  name            = "app-hackathon-${local.clean_provider_slug[each.key]}"
  organization_id = var.organization_id
  description     = "API access for ${each.value.name}"
}

#-------------------------------------------------------------------------------
# IAM API Keys
#-------------------------------------------------------------------------------
# Team API key for their own project (instances, etc.)
resource "scaleway_iam_api_key" "team" {
  for_each           = var.teams
  application_id     = scaleway_iam_application.team[each.key].id
  description        = "API Key for team ${each.value.name} - Project access"
  expires_at         = var.challenge_end_date
  default_project_id = var.team_project_ids[each.key]
}

# NEW: Team API key for S3 access (Zone1 + Livrables) - uses ADMIN project as default
resource "scaleway_iam_api_key" "team_s3" {
  for_each           = var.teams
  application_id     = scaleway_iam_application.team_s3[each.key].id
  description        = "API Key for team ${each.value.name} - S3 access"
  expires_at         = var.challenge_end_date
  default_project_id = var.admin_project_id  # <-- THIS IS THE FIX
}

resource "scaleway_iam_api_key" "admin" {
  application_id     = scaleway_iam_application.admin.id
  description        = "API Key for administrators"
  default_project_id = var.admin_project_id
}

resource "scaleway_iam_api_key" "data_providers" {
  for_each           = var.data_providers
  application_id     = scaleway_iam_application.data_providers[each.key].id
  description        = "API Key for ${each.value.name}"
  expires_at         = var.challenge_end_date
  default_project_id = var.admin_project_id
}

#-------------------------------------------------------------------------------
# IAM Groups
#-------------------------------------------------------------------------------
resource "scaleway_iam_group" "team" {
  for_each        = var.teams
  name            = "group-hackathon-${local.clean_team_slug[each.key]}"
  organization_id = var.organization_id
  description     = "Group for team ${each.value.name}"
  application_ids = [scaleway_iam_application.team[each.key].id]

  user_ids = var.enable_console_access && !var.dry_run ? [
    for m in each.value.members : scaleway_iam_user.all[m].id
    if contains(keys(scaleway_iam_user.all), m)
  ] : []
}

# NEW: Group for S3 access
resource "scaleway_iam_group" "team_s3" {
  for_each        = var.teams
  name            = "group-hackathon-${local.clean_team_slug[each.key]}-s3"
  organization_id = var.organization_id
  description     = "S3 access group for team ${each.value.name}"
  application_ids = [scaleway_iam_application.team_s3[each.key].id]
}

resource "scaleway_iam_group" "admin" {
  name            = "group-hackathon-admin"
  organization_id = var.organization_id
  description     = "Administrators"
  application_ids = [scaleway_iam_application.admin.id]

  user_ids = var.enable_console_access && !var.dry_run ? [
    for m in var.admins.members : scaleway_iam_user.all[m].id
    if contains(keys(scaleway_iam_user.all), m)
  ] : []
}

resource "scaleway_iam_group" "evaluators" {
  name            = "group-hackathon-evaluators"
  organization_id = var.organization_id
  description     = "Evaluators"

  user_ids = var.enable_console_access && !var.dry_run ? [
    for m in var.evaluators.members : scaleway_iam_user.all[m].id
    if contains(keys(scaleway_iam_user.all), m)
  ] : []
}

resource "scaleway_iam_group" "data_providers" {
  for_each        = var.data_providers
  name            = "group-hackathon-${local.clean_provider_slug[each.key]}"
  organization_id = var.organization_id
  description     = "Data provider ${each.value.name}"
  application_ids = [scaleway_iam_application.data_providers[each.key].id]

  user_ids = var.enable_console_access && !var.dry_run ? [
    for m in each.value.members : scaleway_iam_user.all[m].id
    if contains(keys(scaleway_iam_user.all), m)
  ] : []
}

#-------------------------------------------------------------------------------
# IAM Policies - Team access to own project
#-------------------------------------------------------------------------------
resource "scaleway_iam_policy" "team_own_project" {
  for_each        = var.teams
  name            = "policy-hackathon-${local.clean_team_slug[each.key]}-project"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.team[each.key].id
  description     = "Full access for team ${each.value.name}"

  rule {
    project_ids          = [var.team_project_ids[each.key]]
    permission_set_names = ["AllProductsFullAccess"]
  }
}

#-------------------------------------------------------------------------------
# IAM Policies - Team S3 access (Zone1 read + Livrables write)
#-------------------------------------------------------------------------------
resource "scaleway_iam_policy" "team_s3_zone1_read" {
  for_each        = var.teams
  name            = "policy-hackathon-${local.clean_team_slug[each.key]}-s3-zone1"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.team_s3[each.key].id
  description     = "Read access to Zone 1 bucket"

  rule {
    project_ids          = [var.admin_project_id]
    permission_set_names = ["ObjectStorageObjectsRead", "ObjectStorageBucketsRead"]
  }
}

resource "scaleway_iam_policy" "team_s3_livrables_write" {
  for_each        = var.teams
  name            = "policy-hackathon-${local.clean_team_slug[each.key]}-s3-livrables"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.team_s3[each.key].id
  description     = "Write access to Livrables bucket"

  rule {
    project_ids          = [var.admin_project_id]
    permission_set_names = ["ObjectStorageObjectsWrite", "ObjectStorageBucketsRead"]
  }
}

#-------------------------------------------------------------------------------
# IAM Policies - Admin access
#-------------------------------------------------------------------------------
resource "scaleway_iam_policy" "admin_full" {
  name            = "policy-hackathon-admin-full"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.admin.id
  description     = "Full access for admins"

  rule {
    organization_id      = var.organization_id
    permission_set_names = ["AllProductsFullAccess"]
  }
}

resource "scaleway_iam_policy" "admin_project_access" {
  name            = "policy-hackathon-admin-project"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.admin.id
  description     = "Explicit project access for admin buckets"

  rule {
    project_ids          = [var.admin_project_id]
    permission_set_names = ["ObjectStorageFullAccess"]
  }
}

#-------------------------------------------------------------------------------
# IAM Policies - Evaluators access
#-------------------------------------------------------------------------------
resource "scaleway_iam_policy" "evaluators_zone2" {
  name            = "policy-hackathon-evaluators-zone2"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.evaluators.id
  description     = "Read access to Zone 2 and Livrables buckets"

  rule {
    project_ids = [var.admin_project_id]
    permission_set_names = [
      "ObjectStorageObjectsRead",
      "ObjectStorageBucketsRead"
    ]
  }
}

resource "scaleway_iam_policy" "evaluators_teams" {
  name            = "policy-hackathon-evaluators-teams"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.evaluators.id
  description     = "Full read access to all team projects"

  rule {
    project_ids          = values(var.team_project_ids)
    permission_set_names = ["AllProductsReadOnly"]
  }
}

resource "scaleway_iam_application" "evaluators" {
  name            = "app-hackathon-evaluators"
  organization_id = var.organization_id
  description     = "API access for evaluators"
}

resource "scaleway_iam_api_key" "evaluators" {
  application_id     = scaleway_iam_application.evaluators.id
  description        = "API Key for evaluators"
  expires_at         = var.challenge_end_date
  default_project_id = var.admin_project_id
}

resource "scaleway_iam_group_membership" "evaluators_app" {
  group_id       = scaleway_iam_group.evaluators.id
  application_id = scaleway_iam_application.evaluators.id
}

resource "local_sensitive_file" "evaluators_api_keys" {
  filename        = "${path.root}/keys/evaluators/api_credentials.env"
  file_permission = "0600"
  content         = <<-EOT
# API Credentials for Evaluators
# Expires: ${var.challenge_end_date}

export SCW_ACCESS_KEY="${scaleway_iam_api_key.evaluators.access_key}"
export SCW_SECRET_KEY="${scaleway_iam_api_key.evaluators.secret_key}"
export SCW_DEFAULT_ORGANIZATION_ID="${var.organization_id}"
export SCW_DEFAULT_PROJECT_ID="${var.admin_project_id}"
export SCW_DEFAULT_REGION="${var.region}"
export SCW_DEFAULT_ZONE="${var.zone}"
EOT
}

#-------------------------------------------------------------------------------
# IAM Policies - Data Providers access
#-------------------------------------------------------------------------------
resource "scaleway_iam_policy" "data_providers" {
  for_each        = var.data_providers
  name            = "policy-hackathon-${local.clean_provider_slug[each.key]}"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.data_providers[each.key].id
  description     = "RW access to Zone 1 & 2 for ${each.value.name}"

  rule {
    project_ids = [var.admin_project_id]
    permission_set_names = [
      "ObjectStorageObjectsRead",
      "ObjectStorageObjectsWrite",
      "ObjectStorageObjectsDelete",
      "ObjectStorageBucketsRead"
    ]
  }
}

#-------------------------------------------------------------------------------
# Store credentials locally
#-------------------------------------------------------------------------------
resource "local_sensitive_file" "team_api_keys" {
  for_each        = var.teams
  filename        = "${path.root}/keys/${local.clean_team_slug[each.key]}/api_credentials.env"
  file_permission = "0600"
  content         = <<-EOT
# API Credentials for ${each.value.name}
# Expires: ${var.challenge_end_date}

export SCW_ACCESS_KEY="${scaleway_iam_api_key.team[each.key].access_key}"
export SCW_SECRET_KEY="${scaleway_iam_api_key.team[each.key].secret_key}"
export SCW_DEFAULT_ORGANIZATION_ID="${var.organization_id}"
export SCW_DEFAULT_PROJECT_ID="${var.team_project_ids[each.key]}"
export SCW_DEFAULT_REGION="${var.region}"
export SCW_DEFAULT_ZONE="${var.zone}"
EOT
}

# NEW: S3 credentials file for teams
resource "local_sensitive_file" "team_s3_keys" {
  for_each        = var.teams
  filename        = "${path.root}/keys/${local.clean_team_slug[each.key]}/s3_credentials.env"
  file_permission = "0600"
  content         = <<-EOT
# S3 Credentials for ${each.value.name}
# Use these for accessing Zone1 (patients) and Livrables buckets
# Expires: ${var.challenge_end_date}

export S3_ACCESS_KEY="${scaleway_iam_api_key.team_s3[each.key].access_key}"
export S3_SECRET_KEY="${scaleway_iam_api_key.team_s3[each.key].secret_key}"
EOT
}

resource "local_sensitive_file" "admin_api_keys" {
  filename        = "${path.root}/keys/admin/api_credentials.env"
  file_permission = "0600"
  content         = <<-EOT
# API Credentials for Administrators

export SCW_ACCESS_KEY="${scaleway_iam_api_key.admin.access_key}"
export SCW_SECRET_KEY="${scaleway_iam_api_key.admin.secret_key}"
export SCW_DEFAULT_ORGANIZATION_ID="${var.organization_id}"
export SCW_DEFAULT_PROJECT_ID="${var.admin_project_id}"
export SCW_DEFAULT_REGION="${var.region}"
export SCW_DEFAULT_ZONE="${var.zone}"
EOT
}

resource "local_sensitive_file" "data_provider_api_keys" {
  for_each        = var.data_providers
  filename        = "${path.root}/keys/${local.clean_provider_slug[each.key]}/api_credentials.env"
  file_permission = "0600"
  content         = <<-EOT
# API Credentials for ${each.value.name}
# Expires: ${var.challenge_end_date}

export SCW_ACCESS_KEY="${scaleway_iam_api_key.data_providers[each.key].access_key}"
export SCW_SECRET_KEY="${scaleway_iam_api_key.data_providers[each.key].secret_key}"
export SCW_DEFAULT_ORGANIZATION_ID="${var.organization_id}"
export SCW_DEFAULT_PROJECT_ID="${var.admin_project_id}"
export SCW_DEFAULT_REGION="${var.region}"
export SCW_DEFAULT_ZONE="${var.zone}"
EOT
}

#-------------------------------------------------------------------------------
# Outputs
#-------------------------------------------------------------------------------
output "team_api_keys" {
  value = {
    for key, team in var.teams : key => {
      access_key = scaleway_iam_api_key.team[key].access_key
      secret_key = scaleway_iam_api_key.team[key].secret_key
    }
  }
  sensitive = true
}

# NEW: S3 API keys output
output "team_s3_api_keys" {
  value = {
    for key, team in var.teams : key => {
      access_key = scaleway_iam_api_key.team_s3[key].access_key
      secret_key = scaleway_iam_api_key.team_s3[key].secret_key
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
