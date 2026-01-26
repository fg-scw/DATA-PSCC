resource "scaleway_vpc" "vpc" {
  project_id = var.project_id
  name       = format("%s-vpc", var.resource_prefix)
}

resource "scaleway_vpc_private_network" "pn" {
  project_id = var.project_id
  name       = format("%s-pn", var.resource_prefix)
  vpc_id     = scaleway_vpc.vpc.id
}

resource "scaleway_vpc_public_gateway_ip" "gw_ip" {
  project_id = var.project_id
}

resource "scaleway_vpc_public_gateway" "gw" {
  project_id       = var.project_id
  name             = format("%s-gw", var.resource_prefix)
  type             = "VPC-GW-M"
  ip_id            = scaleway_vpc_public_gateway_ip.gw_ip.id
  bastion_enabled  = true
  bastion_port     = 61000
  refresh_ssh_keys = var.ssh_keys_hash
  depends_on       = [scaleway_vpc_private_network.pn]
}

resource "scaleway_vpc_gateway_network" "gw_net" {
  gateway_id         = scaleway_vpc_public_gateway.gw.id
  private_network_id = scaleway_vpc_private_network.pn.id
  enable_masquerade  = true
  ipam_config {
    push_default_route = true
  }
}
