variable "project_name" {
  type = string
}

variable "members" {
  type    = set(string)
  default = []
}

variable "org_id" {
  type = string
}

variable "zone_id" {
  type = string
}
