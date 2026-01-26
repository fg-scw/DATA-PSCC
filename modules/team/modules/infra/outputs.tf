output "pgw_ip" {
  value = scaleway_vpc_public_gateway_ip.gw_ip.address
}

output "instance_ip" {
  value = data.scaleway_ipam_ip.instance.address
}
