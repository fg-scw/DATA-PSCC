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
  value = "keys/${local.team_slug}/connect-gpu.sh"
}

output "ssh_connection_command_alt" {
  value = "ssh -i keys/${local.team_slug}/ssh_private_key.pem -o ProxyCommand=\"ssh -i keys/${local.team_slug}/ssh_private_key.pem -W %%h:%%p -p ${var.bastion_ssh_port} root@${scaleway_instance_ip.bastion.address}\" root@${data.scaleway_ipam_ip.gpu.address}"
}

output "ssh_config_path" {
  value = local_file.ssh_config.filename
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
