output "public_ip" {
  value = scaleway_instance_ip.portal.address
}

output "instance_id" {
  value = scaleway_instance_server.portal.id
}
