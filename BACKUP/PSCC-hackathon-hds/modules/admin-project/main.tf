#===============================================================================
# ADMIN PROJECT MODULE
# Creates the central admin project with Zone 1, Zone 2, and Livrables buckets
#===============================================================================

#-------------------------------------------------------------------------------
# Project
#-------------------------------------------------------------------------------
resource "scaleway_account_project" "admin" {
  name        = "${var.project_prefix}-admin"
  description = "Projet administratif Hackathon HDS - Stockage global"
}

#-------------------------------------------------------------------------------
# Encryption Keys (SSE-C)
#-------------------------------------------------------------------------------
resource "random_bytes" "zone1_encryption_key" {
  length = 32 # AES-256
}

resource "random_bytes" "zone2_encryption_key" {
  length = 32 # AES-256
}

resource "random_bytes" "livrables_encryption_key" {
  length = 32 # AES-256
}

#-------------------------------------------------------------------------------
# Access Logs Bucket
#-------------------------------------------------------------------------------
resource "scaleway_object_bucket" "access_logs" {
  count      = var.enable_access_logs ? 1 : 0
  name       = "${var.bucket_prefix}-access-logs"
  project_id = scaleway_account_project.admin.id
  region     = var.region

  lifecycle_rule {
    enabled = true
    id      = "cleanup-old-logs"

    expiration {
      days = 90
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }
  }

  tags = {
    environment = "hackathon"
    purpose     = "access-logs"
  }
}

#-------------------------------------------------------------------------------
# Zone 1 Bucket - Données patients pour participants
#-------------------------------------------------------------------------------
resource "scaleway_object_bucket" "zone1" {
  name       = "${var.bucket_prefix}-zone1-patients"
  project_id = scaleway_account_project.admin.id
  region     = var.region

  versioning {
    enabled = true
  }

  tags = {
    environment = "hackathon"
    purpose     = "zone1-patients-data"
    sensitivity = "hds"
  }
}

# ACL Zone 1
resource "scaleway_object_bucket_acl" "zone1" {
  bucket     = scaleway_object_bucket.zone1.name
  project_id = scaleway_account_project.admin.id
  region     = var.region
  acl        = "private"
}

#-------------------------------------------------------------------------------
# Zone 2 Bucket - Données évaluation
#-------------------------------------------------------------------------------
resource "scaleway_object_bucket" "zone2" {
  name       = "${var.bucket_prefix}-zone2-evaluation"
  project_id = scaleway_account_project.admin.id
  region     = var.region

  versioning {
    enabled = true
  }

  tags = {
    environment = "hackathon"
    purpose     = "zone2-evaluation-data"
    sensitivity = "hds"
  }
}

# ACL Zone 2
resource "scaleway_object_bucket_acl" "zone2" {
  bucket     = scaleway_object_bucket.zone2.name
  project_id = scaleway_account_project.admin.id
  region     = var.region
  acl        = "private"
}

#-------------------------------------------------------------------------------
# Livrables Bucket - Avec Object Lock COMPLIANCE
#-------------------------------------------------------------------------------
resource "scaleway_object_bucket" "livrables" {
  name       = "${var.bucket_prefix}-livrables"
  project_id = scaleway_account_project.admin.id
  region     = var.region

  versioning {
    enabled = true
  }

  object_lock_enabled = true

  tags = {
    environment = "hackathon"
    purpose     = "livrables"
    retention   = "${var.data_retention_days}days"
  }
}

# ACL Livrables
resource "scaleway_object_bucket_acl" "livrables" {
  bucket     = scaleway_object_bucket.livrables.name
  project_id = scaleway_account_project.admin.id
  region     = var.region
  acl        = "private"
}

# Object Lock Configuration
resource "scaleway_object_bucket_lock_configuration" "livrables" {
  bucket     = scaleway_object_bucket.livrables.name
  project_id = scaleway_account_project.admin.id
  region     = var.region

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.data_retention_days
    }
  }
}

#-------------------------------------------------------------------------------
# Cockpit (Monitoring) - Using new specialized resources
#-------------------------------------------------------------------------------
resource "scaleway_cockpit_source" "admin_metrics" {
  count          = var.enable_cockpit ? 1 : 0
  project_id     = scaleway_account_project.admin.id
  name           = "hackathon-metrics"
  type           = "metrics"
  retention_days = 30
}

resource "scaleway_cockpit_source" "admin_logs" {
  count          = var.enable_cockpit ? 1 : 0
  project_id     = scaleway_account_project.admin.id
  name           = "hackathon-logs"
  type           = "logs"
  retention_days = 30
}

#-------------------------------------------------------------------------------
# Local files - Store encryption keys
#-------------------------------------------------------------------------------
resource "local_sensitive_file" "zone1_key" {
  content         = random_bytes.zone1_encryption_key.base64
  filename        = "${path.root}/keys/zone1_encryption_key.txt"
  file_permission = "0600"
}

resource "local_sensitive_file" "zone2_key" {
  content         = random_bytes.zone2_encryption_key.base64
  filename        = "${path.root}/keys/zone2_encryption_key.txt"
  file_permission = "0600"
}

resource "local_sensitive_file" "livrables_key" {
  content         = random_bytes.livrables_encryption_key.base64
  filename        = "${path.root}/keys/livrables_encryption_key.txt"
  file_permission = "0600"
}
