#===============================================================================
# GENERAL CONFIGURATION
#===============================================================================

variable "organization_id" {
  description = "Scaleway Organization ID"
  type        = string
}

variable "region" {
  description = "Scaleway region"
  type        = string
  default     = "fr-par"
}

variable "zone" {
  description = "Scaleway zone"
  type        = string
  default     = "fr-par-2"
}

variable "project_prefix" {
  description = "Prefix for all project names"
  type        = string
  default     = "hackathon-hds"
}

variable "scw_profile" {
  description = "Scaleway profile name"
  type        = string
  default     = null
}

#===============================================================================
# DEPLOYMENT MODE
#===============================================================================

variable "dry_run" {
  description = "Deploy infrastructure without creating IAM users (no invitations sent)"
  type        = bool
  default     = true
}

#===============================================================================
# HACKATHON TIMING
#===============================================================================

variable "challenge_end_date" {
  description = "Challenge end date (format: YYYY-MM-DDTHH:MM:SSZ)"
  type        = string
}

variable "data_retention_days" {
  description = "Retention period for livrables (Object Lock COMPLIANCE)"
  type        = number
  default     = 365
}

#===============================================================================
# TEAMS CONFIGURATION
#===============================================================================

variable "teams" {
  description = "Map of participating teams"
  type = map(object({
    name    = string
    members = list(string)
  }))
  default = {}
}

variable "enable_console_access" {
  description = "Enable Scaleway console access for participants"
  type        = bool
  default     = false
}

#===============================================================================
# ADMINISTRATORS & DATA PROVIDERS
#===============================================================================

variable "admins" {
  description = "Administrators with full access"
  type = object({
    name    = string
    members = list(string)
  })
  default = {
    name    = "PSCC"
    members = []
  }
}

variable "evaluators" {
  description = "Evaluators with read access to Zone 2"
  type = object({
    name    = string
    members = list(string)
  })
  default = {
    name    = "IPP"
    members = []
  }
}

variable "data_providers" {
  description = "Data providers with RW access on Zone 1 and Zone 2"
  type = map(object({
    name    = string
    members = list(string)
  }))
  default = {}
}

#===============================================================================
# INFRASTRUCTURE SPECS
#===============================================================================

variable "gpu_instance_type" {
  description = "GPU instance type"
  type        = string
  default     = "L40S-1-48G"
}

variable "gpu_root_volume_size_gb" {
  description = "GPU root volume size in GB"
  type        = number
  default     = 200
}

variable "gpu_root_volume_iops" {
  description = "GPU root volume IOPS"
  type        = number
  default     = 15000
}

variable "gpu_image" {
  description = "GPU instance image"
  type        = string
  default     = "ubuntu_jammy_gpu_os_12"
}

variable "bastion_instance_type" {
  description = "Bastion instance type"
  type        = string
  default     = "PRO2-XS"
}

variable "bastion_image" {
  description = "Bastion instance image"
  type        = string
  default     = "ubuntu_jammy"
}

#===============================================================================
# STORAGE CONFIGURATION
#===============================================================================

variable "bucket_prefix" {
  description = "Prefix for bucket names (must be globally unique)"
  type        = string
}

variable "enable_access_logs" {
  description = "Enable S3 access logs"
  type        = bool
  default     = true
}

#===============================================================================
# NETWORK CONFIGURATION
#===============================================================================

variable "vpc_cidr" {
  description = "Base CIDR for VPCs"
  type        = string
  default     = "10.0.0.0/16"
}

variable "bastion_ssh_port" {
  description = "Bastion SSH port"
  type        = number
  default     = 22
}

#===============================================================================
# UPLOAD PORTAL CONFIGURATION
#===============================================================================

variable "enable_upload_portal" {
  description = "Enable upload portal for data providers"
  type        = bool
  default     = false
}

variable "upload_portal_instance_type" {
  description = "Instance type for upload portal"
  type        = string
  default     = "DEV1-S"
}
