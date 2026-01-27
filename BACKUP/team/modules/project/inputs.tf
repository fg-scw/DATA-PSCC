variable "project_name" {
  type = string
}

variable "members" {
  type    = set(string)
  default = []
}

variable "permissions_set" {
  type = set(string)
}

variable "bucket_prefix" {
  type = string
}

variable "org_id" {
  type = string
}

variable "zone_id" {
  type = string
}
