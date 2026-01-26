locals {
  key_file_location = format("%s/ssh_keys/%s", path.root, var.project_name)
}

resource "tls_private_key" "ssh_key" {
  algorithm = "ED25519"
}

locals {
  ssh_public_key  = tls_private_key.ssh_key.public_key_openssh
  ssh_private_key = tls_private_key.ssh_key.private_key_openssh
}

resource "scaleway_iam_ssh_key" "ssh_key" {
  name       = "generated ssh key"
  public_key = local.ssh_public_key
  project_id = scaleway_account_project.project.id
}

resource "local_file" "ssh_public_key" {
  content         = local.ssh_public_key
  filename        = "${local.key_file_location}/public.pem"
  file_permission = "0644"
}

resource "local_file" "ssh_private_key" {
  content         = local.ssh_private_key
  filename        = "${local.key_file_location}/private.pem"
  file_permission = "0600"
}
