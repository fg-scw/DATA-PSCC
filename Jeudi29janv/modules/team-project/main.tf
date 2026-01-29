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
      set -e
      
      # Enable IP forwarding
      sysctl -w net.ipv4.ip_forward=1
      
      # Detect interfaces dynamically
      # Public interface: the one with the default route
      PUBLIC_IF=$(ip route | grep '^default' | awk '{print $5}' | head -1)
      
      # Private interface: the one with 10.x.x.x address (private network)
      PRIVATE_IF=$(ip -o addr show | grep 'inet 10\.' | awk '{print $2}' | head -1)
      
      if [ -z "$PUBLIC_IF" ] || [ -z "$PRIVATE_IF" ]; then
        echo "ERROR: Could not detect interfaces"
        echo "Public: $PUBLIC_IF, Private: $PRIVATE_IF"
        exit 1
      fi
      
      echo "Detected: PUBLIC=$PUBLIC_IF, PRIVATE=$PRIVATE_IF"
      
      # Flush existing rules
      iptables -t nat -F POSTROUTING
      iptables -F FORWARD
      
      # Setup NAT (masquerade outgoing traffic from private network)
      iptables -t nat -A POSTROUTING -o $PUBLIC_IF -j MASQUERADE
      
      # Allow forwarding from private to public
      iptables -A FORWARD -i $PRIVATE_IF -o $PUBLIC_IF -j ACCEPT
      
      # Allow return traffic
      iptables -A FORWARD -i $PUBLIC_IF -o $PRIVATE_IF -m state --state RELATED,ESTABLISHED -j ACCEPT
      
      # Save rules
      mkdir -p /etc/iptables
      iptables-save > /etc/iptables/rules.v4
      
      echo "NAT configured successfully: $PRIVATE_IF -> $PUBLIC_IF"

  - path: /etc/motd
    content: |
      ==============================================================
        HACKATHON HDS - BASTION/NAT - ${replace(var.team_name, "&", "and")}
      ==============================================================
        GPU Access: ssh gpu
        GPU IP: ${local.gpu_private_ip}
        This server provides NAT for the GPU instance.
      ==============================================================

runcmd:
  - systemctl enable fail2ban && systemctl start fail2ban
  - sysctl -p /etc/sysctl.d/99-nat.conf
  # Wait for private network interface to be ready
  - |
    for i in $(seq 1 30); do
      if ip -o addr show | grep -q 'inet 10\.'; then
        echo "Private interface ready"
        break
      fi
      echo "Waiting for private interface... ($i/30)"
      sleep 2
    done
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
  - path: /usr/local/bin/setup-gateway.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # Setup default gateway for GPU instance
      # Auto-detects the bastion IP by finding the first responding host in the subnet
      
      set -e
      
      # Find the private network interface (10.x.x.x)
      PRIVATE_IF=$(ip -o addr show | grep 'inet 10\.' | awk '{print $2}' | head -1)
      
      if [ -z "$PRIVATE_IF" ]; then
        echo "ERROR: Could not detect private interface"
        exit 1
      fi
      
      # Get our IP and subnet
      OUR_IP=$(ip -o addr show dev $PRIVATE_IF | grep 'inet ' | awk '{print $4}' | cut -d/ -f1)
      SUBNET_PREFIX=$(echo $OUR_IP | cut -d. -f1-3)
      
      echo "Detected: interface=$PRIVATE_IF, our_ip=$OUR_IP, subnet=$SUBNET_PREFIX.0/24"
      
      # The bastion is typically at .2 in the subnet (we are at .3 or higher)
      # Try common gateway addresses
      GATEWAY_IP=""
      for candidate in "$SUBNET_PREFIX.2" "$SUBNET_PREFIX.1"; do
        if [ "$candidate" != "$OUR_IP" ]; then
          echo "Trying gateway candidate: $candidate"
          if ping -c 1 -W 2 $candidate > /dev/null 2>&1; then
            GATEWAY_IP=$candidate
            echo "Found responding gateway: $GATEWAY_IP"
            break
          fi
        fi
      done
      
      if [ -z "$GATEWAY_IP" ]; then
        echo "ERROR: Could not find a responding gateway in $SUBNET_PREFIX.0/24"
        echo "Defaulting to $SUBNET_PREFIX.2"
        GATEWAY_IP="$SUBNET_PREFIX.2"
      fi
      
      # Check if default route already exists
      if ip route | grep -q '^default'; then
        echo "Default route already exists, replacing..."
        ip route del default 2>/dev/null || true
      fi
      
      # Add default route via bastion
      ip route add default via $GATEWAY_IP dev $PRIVATE_IF
      
      echo "Default route configured: default via $GATEWAY_IP dev $PRIVATE_IF"
      
      # Verify connectivity
      if ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
        echo "SUCCESS: Internet connectivity verified"
      else
        echo "WARNING: Internet connectivity test failed"
      fi

  - path: /etc/systemd/system/setup-gateway.service
    permissions: '0644'
    content: |
      [Unit]
      Description=Setup default gateway via bastion
      After=network-online.target
      Wants=network-online.target
      
      [Service]
      Type=oneshot
      ExecStartPre=/bin/sleep 10
      ExecStart=/usr/local/bin/setup-gateway.sh
      RemainAfterExit=yes
      StandardOutput=journal
      StandardError=journal
      
      [Install]
      WantedBy=multi-user.target

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
        --s3-sse-customer-key-base64 "$ENCRYPTION_KEY" \
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
        --s3-sse-customer-key-base64 "$LIVRABLES_KEY" \
        --progress

  - path: /root/setup-s3.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # S3 Configuration Script - Auto-detects s3_credentials.env or accepts arguments
      set -e
      
      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      NC='\033[0m'
      
      log_info() { echo -e "$${GREEN}[INFO]$${NC} $1"; }
      log_warn() { echo -e "$${YELLOW}[WARN]$${NC} $1"; }
      log_error() { echo -e "$${RED}[ERROR]$${NC} $1"; }
      
      ACCESS_KEY=""
      SECRET_KEY=""
      
      if [ -n "$1" ] && [ -n "$2" ]; then
        log_info "Using credentials from command line"
        ACCESS_KEY="$1"
        SECRET_KEY="$2"
      elif [ -f /root/s3_credentials.env ]; then
        log_info "Loading from /root/s3_credentials.env"
        source /root/s3_credentials.env
        ACCESS_KEY="$S3_ACCESS_KEY"
        SECRET_KEY="$S3_SECRET_KEY"
      elif [ -f ./s3_credentials.env ]; then
        log_info "Loading from ./s3_credentials.env"
        source ./s3_credentials.env
        ACCESS_KEY="$S3_ACCESS_KEY"
        SECRET_KEY="$S3_SECRET_KEY"
      else
        log_error "No credentials found!"
        echo "Usage: ./setup-s3.sh [ACCESS_KEY SECRET_KEY]"
        echo "Or copy s3_credentials.env to /root/"
        exit 1
      fi
      
      if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
        log_error "Invalid credentials"
        exit 1
      fi
      
      log_info "Configuring S3..."
      
      cat > /root/.env << ENVEOF
      export AWS_ACCESS_KEY_ID=$ACCESS_KEY
      export AWS_SECRET_ACCESS_KEY=$SECRET_KEY
      export ENCRYPTION_KEY="${var.zone1_encryption_key_base64}"
      export LIVRABLES_KEY="${var.zone1_encryption_key_base64}"
      ENVEOF
      
      # Install rclone if needed
      if ! command -v rclone &> /dev/null; then
        log_info "Installing rclone..."
        curl -s https://rclone.org/install.sh | bash
      fi
      
      mkdir -p /root/.config/rclone
      cat > /root/.config/rclone/rclone.conf << RCEOF
      [zone1]
      type = s3
      provider = Scaleway
      region = ${var.region}
      endpoint = s3.${var.region}.scw.cloud
      acl = private
      access_key_id = $ACCESS_KEY
      secret_access_key = $SECRET_KEY
      
      [livrables]
      type = s3
      provider = Scaleway
      region = ${var.region}
      endpoint = s3.${var.region}.scw.cloud
      acl = private
      access_key_id = $ACCESS_KEY
      secret_access_key = $SECRET_KEY
      RCEOF
      
      log_info "Configuration complete!"
      echo "Commands: source /root/.env && ./sync-data.sh"
      
      # Test
      log_info "Testing S3 connection..."
      if rclone lsd zone1: 2>/dev/null; then
        log_info "S3 OK!"
      else
        log_warn "Cannot list buckets (may be normal with restricted access)"
      fi

  - path: /etc/motd
    content: |
      ==============================================================
        HACKATHON HDS - GPU - ${replace(var.team_name, "&", "and")}
      ==============================================================
        GPU: ${var.gpu_instance_type}
        
        Quick Start:
        1. Copy s3_credentials.env to /root/
        2. ./setup-s3.sh
        3. ./sync-data.sh
        
        Or manual: ./setup-s3.sh <ACCESS_KEY> <SECRET_KEY>
        Upload: ./upload-livrable.sh <file>
        Deadline: ${var.challenge_end_date}
      ==============================================================

runcmd:
  - mkdir -p /data/patients /root/.config/rclone
  # Install rclone
  - curl -s https://rclone.org/install.sh | bash || echo "rclone install will be done by setup-s3.sh"
  # Wait for private network interface to be ready
  - |
    for i in $(seq 1 30); do
      if ip -o addr show | grep -q 'inet 10\.'; then
        echo "Private interface ready"
        break
      fi
      echo "Waiting for private interface... ($i/30)"
      sleep 2
    done
  # Setup gateway route and enable persistence
  - /usr/local/bin/setup-gateway.sh
  - systemctl daemon-reload
  - systemctl enable setup-gateway.service
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

#-------------------------------------------------------------------------------
# SSH Config file for easy connection - uses ProxyCommand for reliability
#-------------------------------------------------------------------------------
resource "local_file" "ssh_config" {
  filename        = "${path.root}/keys/${local.team_slug}/ssh_config"
  file_permission = "0600"
  content         = <<-EOT
# SSH Config for ${replace(var.team_name, "&", "and")}
# 
# IMPORTANT: Run from the project root directory (where keys/ folder is located)
# Usage: ssh -F keys/${local.team_slug}/ssh_config gpu

Host bastion-${local.team_slug} bastion
    HostName ${scaleway_instance_ip.bastion.address}
    User root
    Port ${var.bastion_ssh_port}
    IdentityFile keys/${local.team_slug}/ssh_private_key.pem
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new

Host gpu-${local.team_slug} gpu
    HostName ${data.scaleway_ipam_ip.gpu.address}
    User root
    IdentityFile keys/${local.team_slug}/ssh_private_key.pem
    IdentitiesOnly yes
    ProxyCommand ssh -F keys/${local.team_slug}/ssh_config -W %h:%p bastion-${local.team_slug}
    StrictHostKeyChecking accept-new
EOT
}

# Create a standalone connect script that works from any directory
resource "local_file" "connect_script" {
  filename        = "${path.root}/keys/${local.team_slug}/connect-gpu.sh"
  file_permission = "0755"
  content         = <<-EOT
#!/bin/bash
# Connect to GPU for team ${replace(var.team_name, "&", "and")}
# This script can be run from any directory

SCRIPT_DIR="$( cd "$( dirname "$${BASH_SOURCE[0]}" )" && pwd )"
KEY="$SCRIPT_DIR/ssh_private_key.pem"

chmod 600 "$KEY" 2>/dev/null

echo "Connecting to GPU via bastion ${scaleway_instance_ip.bastion.address}..."
ssh -i "$KEY" -o StrictHostKeyChecking=accept-new \
    -o ProxyCommand="ssh -i $KEY -o StrictHostKeyChecking=accept-new -W %h:%p -p ${var.bastion_ssh_port} root@${scaleway_instance_ip.bastion.address}" \
    root@${data.scaleway_ipam_ip.gpu.address}
EOT
}

resource "local_file" "connect_bastion_script" {
  filename        = "${path.root}/keys/${local.team_slug}/connect-bastion.sh"
  file_permission = "0755"
  content         = <<-EOT
#!/bin/bash
# Connect to Bastion for team ${replace(var.team_name, "&", "and")}
# This script can be run from any directory

SCRIPT_DIR="$( cd "$( dirname "$${BASH_SOURCE[0]}" )" && pwd )"
KEY="$SCRIPT_DIR/ssh_private_key.pem"

chmod 600 "$KEY" 2>/dev/null

echo "Connecting to bastion ${scaleway_instance_ip.bastion.address}..."
ssh -i "$KEY" -o StrictHostKeyChecking=accept-new -p ${var.bastion_ssh_port} root@${scaleway_instance_ip.bastion.address}
EOT
}

resource "local_file" "team_credentials" {
  filename        = "${path.root}/keys/${local.team_slug}/credentials.md"
  file_permission = "0600"
  content         = <<-EOT
# Hackathon HDS - ${replace(var.team_name, "&", "and")}

## Quick Start

### Method 1: Using connect script (EASIEST)
```bash
# From the credentials folder, just run:
./connect-gpu.sh
```

### Method 2: Using SSH config (from project root)
```bash
# Must be run from the directory containing keys/ folder
ssh -F keys/${local.team_slug}/ssh_config gpu
```

### Method 3: Direct command (works from anywhere)
```bash
ssh -i /path/to/ssh_private_key.pem \
    -o ProxyCommand="ssh -i /path/to/ssh_private_key.pem -W %h:%p -p ${var.bastion_ssh_port} root@${scaleway_instance_ip.bastion.address}" \
    root@${data.scaleway_ipam_ip.gpu.address}
```

### Method 4: Two-step connection
```bash
# Step 1: Connect to bastion
./connect-bastion.sh
# Or: ssh -i ssh_private_key.pem -p ${var.bastion_ssh_port} root@${scaleway_instance_ip.bastion.address}

# Step 2: From bastion, connect to GPU
ssh gpu
```

## Server IPs
- Bastion (public): ${scaleway_instance_ip.bastion.address}
- GPU (private): ${data.scaleway_ipam_ip.gpu.address}

## Files in this folder
- `ssh_private_key.pem` - SSH private key
- `ssh_config` - SSH configuration file
- `api_credentials.env` - API credentials for S3 access
- `connect-gpu.sh` - Quick connect script to GPU
- `connect-bastion.sh` - Quick connect script to bastion

## On the GPU - Setup S3 access
```bash
# Load your API credentials (from api_credentials.env)
./setup-s3.sh <ACCESS_KEY> <SECRET_KEY>
```

## On the GPU - Useful commands
```bash
./sync-data.sh              # Download patient data from Zone 1
./upload-livrable.sh <file> # Submit your deliverable
nvidia-smi                  # Check GPU status
```

## Deadline
${var.challenge_end_date}
EOT
}
