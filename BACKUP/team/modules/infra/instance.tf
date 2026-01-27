resource "scaleway_instance_security_group" "sg" {
  project_id              = var.project_id
  name                    = "no-public-access"
  inbound_default_policy  = "drop"
  outbound_default_policy = "drop"
  stateful                = true
}

resource "scaleway_instance_volume" "scratch_volume" {
  name       = "ephemeral_storage"
  project_id = var.project_id
  size_in_gb = 3000
  type       = "scratch"
}

resource "scaleway_instance_server" "instance" {
  project_id        = var.project_id
  name              = format("%s-h100", var.resource_prefix)
  type              = "H100-1-80G"
  image             = "ubuntu_jammy_gpu_os_12"
  security_group_id = scaleway_instance_security_group.sg.id
  root_volume {
    volume_type = "sbs_volume"
    sbs_iops    = 15000
    size_in_gb  = 250
  }
  additional_volume_ids = [scaleway_instance_volume.scratch_volume.id]
  depends_on            = [scaleway_vpc_gateway_network.gw_net]
}

resource "scaleway_instance_private_nic" "pnic" {
  server_id          = scaleway_instance_server.instance.id
  private_network_id = scaleway_vpc_private_network.pn.id
}

data "scaleway_ipam_ip" "instance" {
  project_id = var.project_id
  resource {
    id   = scaleway_instance_private_nic.pnic.id
    type = "instance_private_nic"
  }
  type = "ipv4"
}
