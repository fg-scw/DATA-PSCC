#===============================================================================
# IAM GLOBAL MODULE
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
resource "scaleway_iam_api_key" "team" {
  for_each       = var.teams
  application_id = scaleway_iam_application.team[each.key].id
  description    = "API Key for team ${each.value.name}"
  expires_at     = var.challenge_end_date
}

resource "scaleway_iam_api_key" "admin" {
  application_id = scaleway_iam_application.admin.id
  description    = "API Key for administrators"
}

resource "scaleway_iam_api_key" "data_providers" {
  for_each       = var.data_providers
  application_id = scaleway_iam_application.data_providers[each.key].id
  description    = "API Key for ${each.value.name}"
  expires_at     = var.challenge_end_date
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
# IAM Policies - Team access
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

resource "scaleway_iam_policy" "team_zone1_read" {
  for_each        = var.teams
  name            = "policy-hackathon-${local.clean_team_slug[each.key]}-zone1"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.team[each.key].id
  description     = "Read access to Zone 1"

  rule {
    project_ids          = [var.admin_project_id]
    permission_set_names = ["ObjectStorageObjectsRead", "ObjectStorageBucketsRead"]
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

#-------------------------------------------------------------------------------
# IAM Policies - Evaluators access
#-------------------------------------------------------------------------------
resource "scaleway_iam_policy" "evaluators_zone2" {
  name            = "policy-hackathon-evaluators-zone2"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.evaluators.id
  description     = "Read access to Zone 2"

  rule {
    project_ids          = [var.admin_project_id]
    permission_set_names = ["ObjectStorageObjectsRead", "ObjectStorageBucketsRead"]
  }
}

resource "scaleway_iam_policy" "evaluators_teams" {
  name            = "policy-hackathon-evaluators-teams"
  organization_id = var.organization_id
  group_id        = scaleway_iam_group.evaluators.id
  description     = "Read access to all team projects"

  rule {
    project_ids          = values(var.team_project_ids)
    permission_set_names = ["AllProductsReadOnly"]
  }
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
