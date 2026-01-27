variable "project_prefix" {
  description = "Prefix for project name"
  type        = string
}

variable "bucket_prefix" {
  description = "Prefix for bucket names"
  type        = string
}

variable "region" {
  description = "Scaleway region"
  type        = string
}

variable "enable_access_logs" {
  description = "Enable S3 access logs"
  type        = bool
  default     = true
}

variable "enable_cockpit" {
  description = "Enable Cockpit monitoring"
  type        = bool
  default     = true
}

variable "data_retention_days" {
  description = "Retention period for livrables in days"
  type        = number
  default     = 365
}
