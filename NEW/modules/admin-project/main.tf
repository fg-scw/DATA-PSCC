#===============================================================================
# ADMIN PROJECT MODULE
#===============================================================================

resource "scaleway_account_project" "admin" {
  name        = "${var.project_prefix}-admin"
  description = "Hackathon HDS - Admin Project"
}

#-------------------------------------------------------------------------------
# Encryption Keys (SSE-C)
#-------------------------------------------------------------------------------
resource "random_bytes" "zone1_encryption_key" {
  length = 32
}

resource "random_bytes" "zone2_encryption_key" {
  length = 32
}

resource "random_bytes" "livrables_encryption_key" {
  length = 32
}

#-------------------------------------------------------------------------------
# Zone 1 Bucket - Patient data
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
    purpose     = "zone1-patients"
    sensitivity = "hds"
  }
}

resource "scaleway_object_bucket_acl" "zone1" {
  bucket     = scaleway_object_bucket.zone1.name
  project_id = scaleway_account_project.admin.id
  region     = var.region
  acl        = "private"
}

#-------------------------------------------------------------------------------
# Zone 2 Bucket - Evaluation data
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
    purpose     = "zone2-evaluation"
    sensitivity = "hds"
  }
}

resource "scaleway_object_bucket_acl" "zone2" {
  bucket     = scaleway_object_bucket.zone2.name
  project_id = scaleway_account_project.admin.id
  region     = var.region
  acl        = "private"
}

#-------------------------------------------------------------------------------
# Livrables Bucket - With Object Lock
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

resource "scaleway_object_bucket_acl" "livrables" {
  bucket     = scaleway_object_bucket.livrables.name
  project_id = scaleway_account_project.admin.id
  region     = var.region
  acl        = "private"
}

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
  }

  tags = {
    environment = "hackathon"
    purpose     = "access-logs"
  }
}

#-------------------------------------------------------------------------------
# Store encryption keys locally
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
