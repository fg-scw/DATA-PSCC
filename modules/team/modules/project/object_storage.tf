locals {
  ssh_key_prefix = "ssh_keys"
  api_key_prefix = "api_key"
}

resource "scaleway_object_bucket" "bucket" {
  name       = format("%s-%s", var.bucket_prefix, var.project_name)
  project_id = scaleway_account_project.project.id
}

resource "scaleway_object_bucket_acl" "bucket_acl" {
  bucket     = scaleway_object_bucket.bucket.name
  acl        = "private"
  project_id = scaleway_account_project.project.id
}

resource "scaleway_object" "private_ssh_key" {
  bucket        = scaleway_object_bucket.bucket.name
  key           = "${local.ssh_key_prefix}/private_key"
  file          = local_file.ssh_private_key.filename
  storage_class = "ONEZONE_IA"
  visibility    = "private"
  project_id    = scaleway_account_project.project.id
}

resource "scaleway_object" "public_ssh_key" {
  bucket        = scaleway_object_bucket.bucket.name
  key           = "${local.ssh_key_prefix}/public_key"
  file          = local_file.ssh_public_key.filename
  storage_class = "ONEZONE_IA"
  visibility    = "private"
  project_id    = scaleway_account_project.project.id
}

resource "scaleway_object" "api_key" {
  bucket        = scaleway_object_bucket.bucket.name
  key           = "${local.api_key_prefix}/api.env"
  file          = local_file.api.filename
  storage_class = "ONEZONE_IA"
  visibility    = "private"
  project_id    = scaleway_account_project.project.id
}
