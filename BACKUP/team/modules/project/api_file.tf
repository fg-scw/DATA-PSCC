locals {
  api_file_location = format("%s/api_key/%s", path.root, var.project_name)
  region_id         = join("-", slice(split("-", var.zone_id), 0, 2))
}

resource "local_file" "api" {
  filename        = "${local.api_file_location}/api.env"
  file_permission = "0600"
  content         = <<-EOT
    export SCW_ACCESS_KEY=${scaleway_iam_api_key.api.access_key}
    export SCW_SECRET_KEY=${scaleway_iam_api_key.api.secret_key}
    export SCW_DEFAULT_ORGANIZATION_ID=${var.org_id}
    export SCW_DEFAULT_PROJECT_ID=${scaleway_account_project.project.id}
    export SCW_DEFAULT_REGION=${local.region_id}
    export SCW_DEFAULT_ZONE=${var.zone_id}
  EOT
}
