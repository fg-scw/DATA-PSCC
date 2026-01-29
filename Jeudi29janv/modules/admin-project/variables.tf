variable "project_prefix" {
  type = string
}

variable "bucket_prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "enable_access_logs" {
  type    = bool
  default = true
}

variable "data_retention_days" {
  type    = number
  default = 365
}
