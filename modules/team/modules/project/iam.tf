resource "scaleway_iam_user" "members" {
  for_each = var.members
  email    = each.key
}

resource "scaleway_iam_application" "application" {
  name = format("app-%s", var.project_name)
}

resource "scaleway_iam_api_key" "api" {
  application_id = scaleway_iam_application.application.id
  description    = format("Access to project %s resources", var.project_name)
}

resource "scaleway_iam_group" "group" {
  name = format("group-%s", var.project_name)
  application_ids = [
    scaleway_iam_application.application.id
  ]
  user_ids = [for member in scaleway_iam_user.members : member.id]
}

resource "scaleway_iam_policy" "policy" {
  name     = format("policy-%s", var.project_name)
  group_id = scaleway_iam_group.group.id
  rule {
    project_ids          = [scaleway_account_project.project.id]
    permission_set_names = var.permissions_set
  }
}
