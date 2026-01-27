#===============================================================================
# HACKATHON HDS - MAIN TERRAFORM CONFIGURATION
#===============================================================================
# Infrastructure sécurisée pour Data Challenge avec données de santé
# 
# Architecture:
# - 1 projet admin avec buckets Zone 1, Zone 2, Livrables
# - N projets équipes avec VPC, Bastion/NAT, GPU L40S
# - IAM cross-projets pour contrôle d'accès granulaire
#
# Modes:
# - dry_run=true  : Déploie l'infra sans créer les utilisateurs IAM
# - dry_run=false : Déploiement complet avec invitations par email
#===============================================================================

locals {
  # Generate unique CIDR for each team
  team_cidrs = {
    for idx, team_key in keys(var.teams) : team_key => cidrsubnet(var.vpc_cidr, 8, idx)
  }
}

#-------------------------------------------------------------------------------
# Admin Project - Central storage and monitoring
#-------------------------------------------------------------------------------
module "admin_project" {
  source = "./modules/admin-project"

  project_prefix      = var.project_prefix
  bucket_prefix       = var.bucket_prefix
  region              = var.region
  enable_access_logs  = var.enable_access_logs
  enable_cockpit      = var.enable_cockpit
  data_retention_days = var.data_retention_days
}

#-------------------------------------------------------------------------------
# Team Projects - One per participating team
#-------------------------------------------------------------------------------
module "team_projects" {
  for_each = var.teams
  source   = "./modules/team-project"

  project_prefix       = var.project_prefix
  team_name            = each.value.name
  team_members         = each.value.members
  region               = var.region
  zone                 = var.zone
  private_network_cidr = local.team_cidrs[each.key]

  # Instance configuration
  bastion_instance_type   = var.bastion_instance_type
  bastion_image           = var.bastion_image
  bastion_ssh_port        = var.bastion_ssh_port
  gpu_instance_type       = var.gpu_instance_type
  gpu_image               = var.gpu_image
  gpu_root_volume_size_gb = var.gpu_root_volume_size_gb
  gpu_root_volume_iops    = var.gpu_root_volume_iops

  # S3 configuration
  zone1_bucket_name           = module.admin_project.zone1_bucket_name
  livrables_bucket_name       = module.admin_project.livrables_bucket_name
  zone1_encryption_key_base64 = module.admin_project.zone1_encryption_key_base64

  # Dates
  challenge_end_date = var.challenge_end_date

  # Monitoring
  enable_cockpit = var.enable_cockpit

  depends_on = [module.admin_project]
}

#-------------------------------------------------------------------------------
# IAM Global - Cross-project access management
#-------------------------------------------------------------------------------
module "iam_global" {
  source = "./modules/iam-global"

  organization_id = var.organization_id
  region          = var.region
  zone            = var.zone

  teams          = var.teams
  admins         = var.admins
  evaluators     = var.evaluators
  data_providers = var.data_providers

  admin_project_id = module.admin_project.project_id
  team_project_ids = {
    for key, team in var.teams : key => module.team_projects[key].project_id
  }

  enable_console_access = var.enable_console_access
  challenge_end_date    = var.challenge_end_date
  dry_run               = var.dry_run

  depends_on = [module.admin_project, module.team_projects]
}

#-------------------------------------------------------------------------------
# Generate ACCESS.md summary
#-------------------------------------------------------------------------------
resource "local_file" "access_summary" {
  filename = "${path.root}/ACCESS.md"
  content  = <<-EOT
    # Hackathon HDS - Access Information
    
    Generated: ${timestamp()}
    Challenge End Date: ${var.challenge_end_date}
    Mode: ${var.dry_run ? "DRY-RUN (no user invitations sent)" : "PRODUCTION"}
    
    ## Admin Project
    
    - Project ID: ${module.admin_project.project_id}
    - Zone 1 Bucket: ${module.admin_project.zone1_bucket_name}
    - Zone 2 Bucket: ${module.admin_project.zone2_bucket_name}
    - Livrables Bucket: ${module.admin_project.livrables_bucket_name}
    
    ## Team Access
    
    ${join("\n", [
    for key, team in var.teams : <<-TEAM
        ### ${team.name}
        
        - Project ID: ${module.team_projects[key].project_id}
        - Bastion IP: ${module.team_projects[key].bastion_public_ip}
        - GPU Private IP: ${module.team_projects[key].gpu_private_ip}
        - SSH Command: `${module.team_projects[key].ssh_connection_command}`
        - Credentials: `keys/${module.team_projects[key].team_slug}/`
      TEAM
  ])}
    
    ## Encryption Keys
    
    Keys are stored in the `keys/` directory:
    - `keys/zone1_encryption_key.txt` - For Zone 1 bucket
    - `keys/zone2_encryption_key.txt` - For Zone 2 bucket  
    - `keys/livrables_encryption_key.txt` - For Livrables bucket
    
    ## Data Providers
    
    ${join("\n", [
    for key, provider in var.data_providers : <<-PROVIDER
        ### ${provider.name}
        
        - Credentials: `keys/${lower(replace(provider.name, " ", "-"))}/api_credentials.env`
        - Access: Read/Write on Zone 1 & Zone 2 buckets
      PROVIDER
  ])}
    
    ## Important Notes
    
    1. All API keys for participants expire on ${var.challenge_end_date}
    2. Livrables bucket has Object Lock COMPLIANCE mode with ${var.data_retention_days} days retention
    3. All S3 operations require SSE-C encryption with the provided keys
    4. Console access is ${var.enable_console_access ? "ENABLED" : "DISABLED"} for participants
    ${var.dry_run ? "5. DRY-RUN MODE: No user invitations were sent. Set dry_run=false for production deployment." : ""}
  EOT

  lifecycle {
    ignore_changes = [content]
  }
}

#-------------------------------------------------------------------------------
# Generate upload script for data providers
#-------------------------------------------------------------------------------
resource "local_file" "upload_script" {
  filename        = "${path.root}/scripts/upload-to-zone1.sh"
  file_permission = "0755"
  content         = <<-EOT
    #!/bin/bash
    #===============================================================================
    # Upload script for Zone 1 (patient data)
    # Usage: ./upload-to-zone1.sh <source_directory>
    #===============================================================================
    
    set -e
    
    BUCKET="${module.admin_project.zone1_bucket_name}"
    REGION="${var.region}"
    ENCRYPTION_KEY=$(cat keys/zone1_encryption_key.txt)
    
    if [ -z "$1" ]; then
      echo "Usage: $0 <source_directory>"
      echo "Example: $0 /path/to/patient/data"
      exit 1
    fi
    
    SOURCE_DIR="$1"
    
    if [ ! -d "$SOURCE_DIR" ]; then
      echo "Error: Directory $SOURCE_DIR does not exist"
      exit 1
    fi
    
    # Source credentials
    if [ -f "keys/admin/api_credentials.env" ]; then
      source keys/admin/api_credentials.env
    else
      echo "Error: Admin credentials not found. Run 'terraform apply' first."
      exit 1
    fi
    
    echo "Uploading data to Zone 1..."
    echo "Source: $SOURCE_DIR"
    echo "Destination: s3://$BUCKET"
    echo ""
    
    # Configure rclone
    cat > /tmp/rclone-zone1.conf << EOF
    [zone1]
    type = s3
    provider = Scaleway
    access_key_id = $SCW_ACCESS_KEY
    secret_access_key = $SCW_SECRET_KEY
    region = $REGION
    endpoint = s3.$REGION.scw.cloud
    acl = private
    EOF
    
    # Upload with SSE-C
    rclone sync "$SOURCE_DIR" zone1:$BUCKET \
      --config /tmp/rclone-zone1.conf \
      --s3-sse-customer-algorithm AES256 \
      --s3-sse-customer-key "$ENCRYPTION_KEY" \
      --progress \
      --transfers 8 \
      --checkers 16
    
    # Cleanup
    rm -f /tmp/rclone-zone1.conf
    
    echo ""
    echo "✓ Upload complete"
    echo "Files are now available in Zone 1 bucket: $BUCKET"
  EOT
}

resource "local_file" "upload_zone2_script" {
  filename        = "${path.root}/scripts/upload-to-zone2.sh"
  file_permission = "0755"
  content         = <<-EOT
    #!/bin/bash
    #===============================================================================
    # Upload script for Zone 2 (evaluation data)
    # Usage: ./upload-to-zone2.sh <source_directory>
    #===============================================================================
    
    set -e
    
    BUCKET="${module.admin_project.zone2_bucket_name}"
    REGION="${var.region}"
    ENCRYPTION_KEY=$(cat keys/zone2_encryption_key.txt)
    
    if [ -z "$1" ]; then
      echo "Usage: $0 <source_directory>"
      echo "Example: $0 /path/to/evaluation/data"
      exit 1
    fi
    
    SOURCE_DIR="$1"
    
    if [ ! -d "$SOURCE_DIR" ]; then
      echo "Error: Directory $SOURCE_DIR does not exist"
      exit 1
    fi
    
    # Source credentials
    if [ -f "keys/admin/api_credentials.env" ]; then
      source keys/admin/api_credentials.env
    else
      echo "Error: Admin credentials not found. Run 'terraform apply' first."
      exit 1
    fi
    
    echo "Uploading data to Zone 2..."
    echo "Source: $SOURCE_DIR"
    echo "Destination: s3://$BUCKET"
    echo ""
    
    # Configure rclone
    cat > /tmp/rclone-zone2.conf << EOF
    [zone2]
    type = s3
    provider = Scaleway
    access_key_id = $SCW_ACCESS_KEY
    secret_access_key = $SCW_SECRET_KEY
    region = $REGION
    endpoint = s3.$REGION.scw.cloud
    acl = private
    EOF
    
    # Upload with SSE-C
    rclone sync "$SOURCE_DIR" zone2:$BUCKET \
      --config /tmp/rclone-zone2.conf \
      --s3-sse-customer-algorithm AES256 \
      --s3-sse-customer-key "$ENCRYPTION_KEY" \
      --progress \
      --transfers 8 \
      --checkers 16
    
    # Cleanup
    rm -f /tmp/rclone-zone2.conf
    
    echo ""
    echo "✓ Upload complete"
    echo "Files are now available in Zone 2 bucket: $BUCKET"
  EOT
}
