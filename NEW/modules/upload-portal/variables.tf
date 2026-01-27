variable "project_prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "admin_project_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "DEV1-S"
}

variable "zone1_bucket_name" {
  type = string
}

variable "zone2_bucket_name" {
  type = string
}

variable "livrables_bucket_name" {
  type = string
}

variable "zone1_encryption_key" {
  type      = string
  sensitive = true
}

variable "zone2_encryption_key" {
  type      = string
  sensitive = true
}

variable "livrables_encryption_key" {
  type      = string
  sensitive = true
}

variable "data_providers" {
  type = map(object({
    name    = string
    members = list(string)
  }))
}

variable "scw_access_key" {
  type      = string
  sensitive = true
}

variable "scw_secret_key" {
  type      = string
  sensitive = true
}
