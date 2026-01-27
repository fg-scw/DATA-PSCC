#===============================================================================
# IAM GLOBAL MODULE
# Manages IAM users, groups, policies across all projects
#===============================================================================

locals {
  # Fonction pour nettoyer les noms (remplace & par "and", garde uniquement les caractères valides)
  clean_team_name = {
    for k, v in var.teams : k => replace(replace(v.name, "&", "and"), "/[^a-zA-Z0-9()._\\- ]/", "")
  }

  clean_team_slug = {
    for k, v in var.teams : k => replace(lower(replace(replace(v.name, "&", "and"), " ", "-")), "/[^a-z0-9\\-]/", "")
  }

  clean_data_provider_name = {
    for k, v in var.data_providers : k => replace(replace(v.name, "&", "and"), "/[^a-zA-Z0-9()._\\- ]/", "")
  }

  clean_data_provider_slug = {
    for k, v in var.data_providers : k => replace(lower(replace(replace(v.name, "&", "and"), " ", "-")), "/[^a-z0-9\\-]/", "")
  }

  # Flatten all team members
  all_team_members = flatten([
    for team_key, team in var.teams : [
      for member in team.members : {
        team_key  = team_key
        team_name = team.name
        email     = member
      }
    ]
  ])

  # Flatten all admin members
  all_admin_members = [for member in var.admins.members : member]

  # Flatten all evaluator members
  all_evaluator_members = [for member in var.evaluators.members : member]

  # Flatten all data provider members
  all_data_provider_members = flatten([
    for provider_key, provider in var.data_providers : [
      for member in provider.members : {
        provider_key  = provider_key
        provider_name = provider.name
        email         = member
      }
    ]
  ])

  # All unique emails for user creation
  all_emails = distinct(concat(
    [for m in local.all_team_members : m.email],
    local.all_admin_members,
    local.all_evaluator_members,
    [for m in local.all_data_provider_members : m.email]
  ))
}

#-------------------------------------------------------------------------------
# IAM Users - Create all users (skipped in dry_run mode)
#-------------------------------------------------------------------------------
resource "scaleway_iam_user" "all" {
  for_each        = var.enable_console_access && !var.dry_run ? toset(local.all_emails) : toset([])
  email           = each.value
  username        = replace(split("@", each.value)[0], ".", "-")
  organization_id = var.organization_id
}

#-------------------------------------------------------------------------------
# IAM Applications - For API access (one per team + admin groups)
#-------------------------------------------------------------------------------

# Application for each team
resource "scaleway_iam_application" "team" {
  for_each        = var.teams
  name            = "app-hackathon-${local.clean_team_slug[each.key]}"
  organization_id = var.organization_id
  description     = "API access for team ${local.clean_team_name[each.key]}"
}

# Application for admins
resource "scaleway_iam_application" "admin" {
  name            = "app-hackathon-admin"
  organization_id = var.organization_id
  description     = "API access for hackathon administrators"
}

# Application for data providers
resource "scaleway_iam_application" "data_providers" {
  for_each        = var.data_providers
  name            = "app-hackathon-${local.clean_data_provider_slug[each.key]}"
  organization_id = var.organization_id
  description     = "API access for data provider ${local.clean_data_provider_name[each.key]}"
}

#-------------------------------------------------------------------------------
# IAM API Keys - With expiration date
#-------------------------------------------------------------------------------

# API Key for each team (for S3 access from GPU)
resource "scaleway_iam_api_key" "team" {
  for_each       = var.teams
  application_id = scaleway_iam_application.team[each.key].id
  description    = "API Key for team ${local.clean_team_name[each.key]}"
  expires_at     = var.challenge_end_date
}

# API Key for admins
resource "scaleway_iam_api_key" "admin" {
  application_id = scaleway_iam_application.admin.id
  description    = "API Key for hackathon administrators"
  # No expiration for admins
}

# API Keys for data providers
resource "scaleway_iam_api_key" "data_providers" {
  for_each       = var.data_providers
  application_id = scaleway_iam_application.data_providers[each.key].id
  description    = "API Key for ${local.clean_data_provider_name[each.key]}"
  expires_at     = var.challenge_end_date
}

#-------------------------------------------------------------------------------
# IAM Groups
#-------------------------------------------------------------------------------

# Group for each team
resource "scaleway_iam_group" "team" {
  for_each        = var.teams
  name            = "group-hackathon-${local.clean_team_slug[each.key]}"
  organization_id = var.organization_id
  description     = "Group for team ${local.clean_team_name[each.key]}"

  application_ids = [scaleway_iam_application.team[each.key].id]

  user_ids = var.enable_console_access && !var.dry_run ? [
    for member in each.value.members : scaleway_iam_user.all[member].id
    if contains(keys(scaleway_iam_user.all), member)
  ] : []
}

# Group for admins
resource "scaleway_iam_group" "admin" {
  name            = "group-hackathon-admin"
  organization_id = var.organization_id
  description     = "Hackathon administrators (PSCC)"

  application_ids = [scaleway_iam_application.admin.id]

  user_ids = var.enable_console_access && !var.dry_run ? [
    for member in var.admins.members : scaleway_iam_user.all[member].id
    if contains(keys(scaleway_iam_user.all), member)
  ] : []
}

# Group for evaluators
resource "scaleway_iam_group" "evaluators" {
  name            = "group-hackathon-evaluators"
  organization_id = var.organization_id
  description     = "Hackathon evaluators (IPP)"

  user_ids = var.enable_console_access && !var.dry_run ? [
    for member in var.evaluators.members : scaleway_iam_user.all[member].id
    if contains(keys(scaleway_iam_user.all), member)
  ] : []
}

# Group for each data provider
resource "scaleway_iam_group" "data_providers" {
  for_each        = var.data_providers
  name            = "group-hackathon-${local.clean_data_provider_slug[each.key]}"
  organization_id = var.organization_id
  description     = "Data provider ${local.clean_data_provider_name[each.key]}"

  application_ids = [scaleway_iam_application.data_providers[each.key].id]

  user_ids = var.enable_console_access && !var.dry_run ? [
    for member in each.value.members : scaleway_iam_user.all[member].id
    if contains(keys(scaleway_iam_user.all), member)
  ] : []
}

#-------------------------------------------------------------------------------
# IAM Policies - Team access to their own project
#-------------------------------------------------------------------------------

# Each team gets full access to their project
resource "scaleway_iam_policy" "team_own_project" {
  for_each        = var.teams
  name            = "policy-hackathon-${local.clean_team_slug[each.key]}-project"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.team[each.key].id
  description     = "Full access for team ${local.clean_team_name[each.key]} to their project"

  rule {
    project_ids          = [var.team_project_ids[each.key]]
    permission_set_names = ["AllProductsFullAccess"]
  }
}

# Each team gets read access to Zone 1 bucket (admin project)
resource "scaleway_iam_policy" "team_zone1_read" {
  for_each        = var.teams
  name            = "policy-hackathon-${local.clean_team_slug[each.key]}-zone1"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.team[each.key].id
  description     = "Read access to Zone 1 for team ${local.clean_team_name[each.key]}"

  rule {
    project_ids          = [var.admin_project_id]
    permission_set_names = ["ObjectStorageObjectsRead", "ObjectStorageBucketsRead"]
  }
}

#-------------------------------------------------------------------------------
# IAM Policies - Admin access
#-------------------------------------------------------------------------------

# Admins get full access to admin project
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

#-------------------------------------------------------------------------------
# IAM Policies - Evaluators access
#-------------------------------------------------------------------------------

# Evaluators get read access to Zone 2 and all team projects
resource "scaleway_iam_policy" "evaluators_zone2" {
  name            = "policy-hackathon-evaluators-zone2"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.evaluators.id
  description     = "Read access to Zone 2 for evaluators"

  rule {
    project_ids          = [var.admin_project_id]
    permission_set_names = ["ObjectStorageObjectsRead", "ObjectStorageBucketsRead"]
  }
}

# Evaluators get read access to all team projects
resource "scaleway_iam_policy" "evaluators_teams" {
  name            = "policy-hackathon-evaluators-teams"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.evaluators.id
  description     = "Read access to all team projects for evaluators"

  rule {
    project_ids          = values(var.team_project_ids)
    permission_set_names = ["AllProductsReadOnly"]
  }
}

#-------------------------------------------------------------------------------
# IAM Policies - Data Providers access
#-------------------------------------------------------------------------------

# Data providers get write access to Zone 1 and Zone 2
resource "scaleway_iam_policy" "data_providers" {
  for_each        = var.data_providers
  name            = "policy-hackathon-${local.clean_data_provider_slug[each.key]}"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.data_providers[each.key].id
  description     = "Read/Write access to Zone 1 and 2 for ${local.clean_data_provider_name[each.key]}"

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
# Store API keys locally
#-------------------------------------------------------------------------------

resource "local_sensitive_file" "team_api_keys" {
  for_each        = var.teams
  filename        = "${path.root}/keys/${local.clean_team_slug[each.key]}/api_credentials.env"
  file_permission = "0600"
  content         = <<-EOT
    # API Credentials for ${local.clean_team_name[each.key]}
    # Expires: ${var.challenge_end_date}
    
    export SCW_ACCESS_KEY="${scaleway_iam_api_key.team[each.key].access_key}"
    export SCW_SECRET_KEY="${scaleway_iam_api_key.team[each.key].secret_key}"
    export SCW_DEFAULT_ORGANIZATION_ID="${var.organization_id}"
    export SCW_DEFAULT_PROJECT_ID="${var.team_project_ids[each.key]}"
    export SCW_DEFAULT_REGION="${var.region}"
    export SCW_DEFAULT_ZONE="${var.zone}"
  EOT
}

resource "local_sensitive_file" "admin_api_keys" {
  filename        = "${path.root}/keys/admin/api_credentials.env"
  file_permission = "0600"
  content         = <<-EOT
    # API Credentials for Hackathon Administrators
    
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
  filename        = "${path.root}/keys/${local.clean_data_provider_slug[each.key]}/api_credentials.env"
  file_permission = "0600"
  content         = <<-EOT
    # API Credentials for ${local.clean_data_provider_name[each.key]}
    # Expires: ${var.challenge_end_date}
    
    export SCW_ACCESS_KEY="${scaleway_iam_api_key.data_providers[each.key].access_key}"
    export SCW_SECRET_KEY="${scaleway_iam_api_key.data_providers[each.key].secret_key}"
    export SCW_DEFAULT_ORGANIZATION_ID="${var.organization_id}"
    export SCW_DEFAULT_PROJECT_ID="${var.admin_project_id}"
    export SCW_DEFAULT_REGION="${var.region}"
    export SCW_DEFAULT_ZONE="${var.zone}"
  EOT
}
