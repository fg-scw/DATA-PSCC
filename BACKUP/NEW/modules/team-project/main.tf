#===============================================================================
# TEAM PROJECT MODULE
# Creates project with VPC, Bastion/NAT Instance, and GPU for each team
# Architecture: Bastion acts as NAT gateway for GPU (HDS compliant)
#===============================================================================

locals {
  team_slug_raw = lower(replace(replace(var.team_name, "&", "and"), " ", "-"))
  team_slug     = replace(local.team_slug_raw, "/[^a-z0-9\\-]/", "")
  
  network_prefix     = split("/", var.private_network_cidr)[0]
  network_parts      = split(".", local.network_prefix)
  bastion_private_ip = "${local.network_parts[0]}.${local.network_parts[1]}.${local.network_parts[2]}.2"
  gpu_private_ip     = "${local.network_parts[0]}.${local.network_parts[1]}.${local.network_parts[2]}.3"
}

#-------------------------------------------------------------------------------
# Project
#-------------------------------------------------------------------------------
resource "scaleway_account_project" "team" {
  name        = "${var.project_prefix}-${local.team_slug}"
  description = "Hackathon HDS - Team ${replace(var.team_name, "&", "and")}"
}

#-------------------------------------------------------------------------------
# Credentials Bucket - Store team credentials
#-------------------------------------------------------------------------------
resource "scaleway_object_bucket" "credentials" {
  name       = "${var.project_prefix}-${local.team_slug}-credentials"
  project_id = scaleway_account_project.team.id
  region     = var.region

  tags = {
    environment = "hackathon"
    purpose     = "team-credentials"
    team        = local.team_slug
  }
}

resource "scaleway_object_bucket_acl" "credentials" {
  bucket     = scaleway_object_bucket.credentials.name
  project_id = scaleway_account_project.team.id
  region     = var.region
  acl        = "private"
}

#-------------------------------------------------------------------------------
# SSH Key
#-------------------------------------------------------------------------------
resource "tls_private_key" "team" {
  algorithm = "ED25519"
}

resource "scaleway_iam_ssh_key" "team" {
  name       = "${local.team_slug}-ssh-key"
  public_key = tls_private_key.team.public_key_openssh
  project_id = scaleway_account_project.team.id
}

#-------------------------------------------------------------------------------
# VPC & Private Network
#-------------------------------------------------------------------------------
resource "scaleway_vpc" "team" {
  name       = "${local.team_slug}-vpc"
  project_id = scaleway_account_project.team.id
  region     = var.region
  tags       = ["hackathon", local.team_slug]
}

resource "scaleway_vpc_private_network" "team" {
  name       = "${local.team_slug}-pn"
  project_id = scaleway_account_project.team.id
  region     = var.region
  vpc_id     = scaleway_vpc.team.id

  ipv4_subnet {
    subnet = var.private_network_cidr
  }

  tags = ["hackathon", local.team_slug]
}

#-------------------------------------------------------------------------------
# Security Groups
#-------------------------------------------------------------------------------
resource "scaleway_instance_security_group" "bastion" {
  project_id              = scaleway_account_project.team.id
  zone                    = var.zone
  name                    = "${local.team_slug}-bastion-sg"
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"
  stateful                = true

  inbound_rule {
    action   = "accept"
    port     = var.bastion_ssh_port
    protocol = "TCP"
  }

  inbound_rule {
    action   = "accept"
    protocol = "ICMP"
  }
}

resource "scaleway_instance_security_group" "gpu" {
  project_id              = scaleway_account_project.team.id
  zone                    = var.zone
  name                    = "${local.team_slug}-gpu-sg"
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"
  stateful                = true

  inbound_rule {
    action   = "accept"
    port     = 22
    protocol = "TCP"
    ip_range = var.private_network_cidr
  }

  inbound_rule {
    action   = "accept"
    protocol = "ICMP"
    ip_range = var.private_network_cidr
  }
}

#-------------------------------------------------------------------------------
# Bastion Instance - Acts as SSH jump host AND NAT gateway
#-------------------------------------------------------------------------------
resource "scaleway_instance_ip" "bastion" {
  project_id = scaleway_account_project.team.id
  zone       = var.zone
  tags       = ["hackathon", local.team_slug, "bastion"]
}

resource "scaleway_instance_server" "bastion" {
  project_id = scaleway_account_project.team.id
  zone       = var.zone
  name       = "${local.team_slug}-bastion"
  type       = var.bastion_instance_type
  image      = var.bastion_image

  ip_id             = scaleway_instance_ip.bastion.id
  security_group_id = scaleway_instance_security_group.bastion.id

  root_volume {
    size_in_gb  = 20
    volume_type = "sbs_volume"
    sbs_iops    = 5000
  }

  user_data = {
    cloud-init = <<-CLOUDINIT
#cloud-config
package_update: true
packages:
  - fail2ban
  - iptables
  - iptables-persistent

write_files:
  - path: /root/.ssh/id_ed25519
    permissions: '0600'
    content: |
      ${indent(6, tls_private_key.team.private_key_openssh)}

  - path: /root/.ssh/config
    permissions: '0600'
    content: |
      Host gpu
        HostName ${local.gpu_private_ip}
        User root
        IdentityFile /root/.ssh/id_ed25519
        StrictHostKeyChecking accept-new

  - path: /etc/sysctl.d/99-nat.conf
    content: |
      net.ipv4.ip_forward = 1

  - path: /usr/local/bin/setup-nat.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # Enable IP forwarding
      sysctl -w net.ipv4.ip_forward=1
      
      # Get interfaces
      PUBLIC_IF="ens2"
      PRIVATE_IF=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^ens[0-9]+$' | tail -1)
      
      # Setup NAT
      iptables -t nat -F POSTROUTING
      iptables -t nat -A POSTROUTING -o $PUBLIC_IF -j MASQUERADE
      iptables -A FORWARD -i $PRIVATE_IF -o $PUBLIC_IF -j ACCEPT
      iptables -A FORWARD -i $PUBLIC_IF -o $PRIVATE_IF -m state --state RELATED,ESTABLISHED -j ACCEPT
      
      # Save rules
      iptables-save > /etc/iptables/rules.v4
      echo "NAT configured: $PRIVATE_IF -> $PUBLIC_IF"

  - path: /etc/motd
    content: |
      ══════════════════════════════════════════════════════════════
        HACKATHON HDS - BASTION/NAT - ${replace(var.team_name, "&", "and")}
      ══════════════════════════════════════════════════════════════
        GPU Access: ssh gpu
        GPU IP: ${local.gpu_private_ip}
        This server provides NAT for the GPU instance.
      ══════════════════════════════════════════════════════════════

runcmd:
  - systemctl enable fail2ban && systemctl start fail2ban
  - sysctl -p /etc/sysctl.d/99-nat.conf
  - sleep 10
  - /usr/local/bin/setup-nat.sh
  - netfilter-persistent save
CLOUDINIT
  }

  tags = ["hackathon", local.team_slug, "bastion"]

  lifecycle {
    ignore_changes = [user_data]
  }
}

resource "scaleway_instance_private_nic" "bastion" {
  server_id          = scaleway_instance_server.bastion.id
  private_network_id = scaleway_vpc_private_network.team.id
  zone               = var.zone
}

#-------------------------------------------------------------------------------
# Get Bastion private IP from IPAM
#-------------------------------------------------------------------------------
data "scaleway_ipam_ip" "bastion" {
  resource {
    id   = scaleway_instance_private_nic.bastion.id
    type = "instance_private_nic"
  }
  type = "ipv4"

  depends_on = [scaleway_instance_private_nic.bastion]
}

#-------------------------------------------------------------------------------
# GPU Instance
#-------------------------------------------------------------------------------
resource "scaleway_instance_server" "gpu" {
  project_id = scaleway_account_project.team.id
  zone       = var.zone
  name       = "${local.team_slug}-gpu"
  type       = var.gpu_instance_type
  image      = var.gpu_image

  security_group_id = scaleway_instance_security_group.gpu.id
  ip_id             = null  # No public IP

  root_volume {
    size_in_gb  = var.gpu_root_volume_size_gb
    volume_type = "sbs_volume"
    sbs_iops    = var.gpu_root_volume_iops
  }

  user_data = {
    cloud-init = <<-CLOUDINIT
#cloud-config
package_update: true
packages:
  - awscli
  - rclone
  - jq

write_files:
  - path: /etc/netplan/99-default-route.yaml
    permissions: '0644'
    content: |
      network:
        version: 2
        ethernets:
          ens5:
            routes:
              - to: default
                via: ${data.scaleway_ipam_ip.bastion.address}

  - path: /root/.config/rclone/rclone.conf
    permissions: '0600'
    content: |
      [zone1]
      type = s3
      provider = Scaleway
      region = ${var.region}
      endpoint = s3.${var.region}.scw.cloud
      acl = private

  - path: /root/sync-data.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      source /root/.env 2>/dev/null || { echo "Run setup-s3.sh first"; exit 1; }
      mkdir -p /data/patients
      rclone sync zone1:${var.zone1_bucket_name} /data/patients/ \
        --s3-sse-customer-algorithm AES256 \
        --s3-sse-customer-key "$ENCRYPTION_KEY" \
        --progress

  - path: /root/upload-livrable.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      source /root/.env 2>/dev/null || { echo "Run setup-s3.sh first"; exit 1; }
      [ -z "$1" ] && { echo "Usage: $0 <file>"; exit 1; }
      TIMESTAMP=$(date +%Y%m%d_%H%M%S)
      rclone copy "$1" zone1:${var.livrables_bucket_name}/$TIMESTAMP/ \
        --s3-sse-customer-algorithm AES256 \
        --s3-sse-customer-key "$LIVRABLES_KEY" \
        --progress

  - path: /root/setup-s3.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      [ -z "$1" ] || [ -z "$2" ] && { echo "Usage: $0 <ACCESS_KEY> <SECRET_KEY>"; exit 1; }
      cat > /root/.env << EOF
      export AWS_ACCESS_KEY_ID=$1
      export AWS_SECRET_ACCESS_KEY=$2
      export ENCRYPTION_KEY="${var.zone1_encryption_key_base64}"
      export LIVRABLES_KEY="${var.zone1_encryption_key_base64}"
      EOF
      cat >> /root/.config/rclone/rclone.conf << EOF
      access_key_id = $1
      secret_access_key = $2
      EOF
      echo "S3 configured. Run: source /root/.env"

  - path: /etc/motd
    content: |
      ══════════════════════════════════════════════════════════════
        HACKATHON HDS - GPU - ${replace(var.team_name, "&", "and")}
      ══════════════════════════════════════════════════════════════
        GPU: ${var.gpu_instance_type}
        Setup: ./setup-s3.sh <ACCESS_KEY> <SECRET_KEY>
        Sync data: ./sync-data.sh
        Upload: ./upload-livrable.sh <file>
        Deadline: ${var.challenge_end_date}
      ══════════════════════════════════════════════════════════════

runcmd:
  - mkdir -p /data/patients /root/.config/rclone
  - netplan apply || true
  - nvidia-smi || echo "GPU will be ready after reboot"
CLOUDINIT
  }

  tags = ["hackathon", local.team_slug, "gpu", var.gpu_instance_type]

  depends_on = [
    scaleway_instance_private_nic.bastion,
    data.scaleway_ipam_ip.bastion
  ]

  lifecycle {
    ignore_changes = [user_data]
  }
}

resource "scaleway_instance_private_nic" "gpu" {
  server_id          = scaleway_instance_server.gpu.id
  private_network_id = scaleway_vpc_private_network.team.id
  zone               = var.zone
}

#-------------------------------------------------------------------------------
# Get GPU private IP from IPAM
#-------------------------------------------------------------------------------
data "scaleway_ipam_ip" "gpu" {
  resource {
    id   = scaleway_instance_private_nic.gpu.id
    type = "instance_private_nic"
  }
  type = "ipv4"

  depends_on = [scaleway_instance_private_nic.gpu]
}

#-------------------------------------------------------------------------------
# Local files
#-------------------------------------------------------------------------------
resource "local_sensitive_file" "ssh_private_key" {
  content         = tls_private_key.team.private_key_openssh
  filename        = "${path.root}/keys/${local.team_slug}/ssh_private_key.pem"
  file_permission = "0600"
}

resource "local_file" "ssh_public_key" {
  content         = tls_private_key.team.public_key_openssh
  filename        = "${path.root}/keys/${local.team_slug}/ssh_public_key.pub"
  file_permission = "0644"
}

resource "local_file" "team_credentials" {
  filename        = "${path.root}/keys/${local.team_slug}/credentials.md"
  file_permission = "0600"
  content         = <<-EOT
# Hackathon HDS - ${replace(var.team_name, "&", "and")}

## SSH Access

### Direct connection (via ProxyJump)
```bash
ssh -i ssh_private_key.pem -J root@${scaleway_instance_ip.bastion.address}:${var.bastion_ssh_port} root@${data.scaleway_ipam_ip.gpu.address}
```

### Two-step connection
```bash
# Connect to bastion
ssh -i ssh_private_key.pem -p ${var.bastion_ssh_port} root@${scaleway_instance_ip.bastion.address}

# From bastion, connect to GPU
ssh gpu
```

## IPs
- Bastion: ${scaleway_instance_ip.bastion.address}
- GPU: ${data.scaleway_ipam_ip.gpu.address}

## S3 Setup (run on GPU)
```bash
./setup-s3.sh <ACCESS_KEY> <SECRET_KEY>
```

## Useful commands
```bash
./sync-data.sh           # Download patient data
./upload-livrable.sh <file>  # Submit deliverable
```

## Deadline
${var.challenge_end_date}
EOT
}
