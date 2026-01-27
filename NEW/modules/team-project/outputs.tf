output "project_id" {
  value = scaleway_account_project.team.id
}

output "project_name" {
  value = scaleway_account_project.team.name
}

output "team_name" {
  value = var.team_name
}

output "team_slug" {
  value = local.team_slug
}

output "bastion_public_ip" {
  value = scaleway_instance_ip.bastion.address
}

output "gpu_private_ip" {
  value = data.scaleway_ipam_ip.gpu.address
}

output "gpu_instance_id" {
  value = scaleway_instance_server.gpu.id
}

output "bastion_instance_id" {
  value = scaleway_instance_server.bastion.id
}

output "ssh_connection_command" {
  value = "ssh -i keys/${local.team_slug}/ssh_private_key.pem -J root@${scaleway_instance_ip.bastion.address}:${var.bastion_ssh_port} root@${data.scaleway_ipam_ip.gpu.address}"
}

output "vpc_id" {
  value = scaleway_vpc.team.id
}

output "private_network_id" {
  value = scaleway_vpc_private_network.team.id
}

output "ssh_private_key_path" {
  value = local_sensitive_file.ssh_private_key.filename
}

output "credentials_bucket_name" {
  value = scaleway_object_bucket.credentials.name
}
