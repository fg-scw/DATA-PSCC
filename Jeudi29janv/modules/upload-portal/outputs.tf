output "public_ip" {
  value = scaleway_instance_ip.portal.address
}

output "instance_id" {
  value = scaleway_instance_server.portal.id
}

output "ssh_command" {
  value = "ssh -i keys/upload-portal/ssh_private_key.pem root@${scaleway_instance_ip.portal.address}"
}

output "ssh_private_key_path" {
  value = local_sensitive_file.portal_ssh_key.filename
}
