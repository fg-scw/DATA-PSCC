output "project_id" {
  description = "Team project ID"
  value       = scaleway_account_project.team.id
}

output "project_name" {
  description = "Team project name"
  value       = scaleway_account_project.team.name
}

output "team_name" {
  description = "Team display name"
  value       = var.team_name
}

output "team_slug" {
  description = "Team slug (lowercase, no spaces)"
  value       = local.team_slug
}

output "bastion_public_ip" {
  description = "Bastion public IP"
  value       = scaleway_instance_ip.bastion.address
}

output "bastion_private_ip" {
  description = "Bastion private IP"
  value       = data.scaleway_ipam_ip.bastion.address
}

output "gpu_private_ip" {
  description = "GPU instance private IP"
  value       = data.scaleway_ipam_ip.gpu.address
}

output "gpu_instance_id" {
  description = "GPU instance ID"
  value       = scaleway_instance_server.gpu.id
}

output "bastion_instance_id" {
  description = "Bastion instance ID"
  value       = scaleway_instance_server.bastion.id
}

output "ssh_connection_command" {
  description = "SSH command to connect to GPU via bastion"
  value       = "ssh -i keys/${local.team_slug}/ssh_private_key.pem -J root@${scaleway_instance_ip.bastion.address}:${var.bastion_ssh_port} root@${data.scaleway_ipam_ip.gpu.address}"
}

output "vpc_id" {
  description = "VPC ID"
  value       = scaleway_vpc.team.id
}

output "private_network_id" {
  description = "Private network ID"
  value       = scaleway_vpc_private_network.team.id
}

output "ssh_private_key_path" {
  description = "Path to SSH private key"
  value       = local_sensitive_file.ssh_private_key.filename
}
