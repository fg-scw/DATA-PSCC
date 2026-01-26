output "project_id" {
  value = scaleway_account_project.project.id
}

output "ssh_keys_hash" {
  value = sha256(join(",", [scaleway_iam_ssh_key.ssh_key.public_key]))
}
