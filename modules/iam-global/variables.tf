variable "organization_id" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "teams" {
  type = map(object({
    name    = string
    members = list(string)
  }))
}

variable "admins" {
  type = object({
    name    = string
    members = list(string)
  })
}

variable "evaluators" {
  type = object({
    name    = string
    members = list(string)
  })
}

variable "data_providers" {
  type = map(object({
    name    = string
    members = list(string)
  }))
}

variable "admin_project_id" {
  type = string
}

variable "team_project_ids" {
  type = map(string)
}

variable "team_credentials_bucket_names" {
  type = map(string)
}

variable "enable_console_access" {
  type    = bool
  default = false
}

variable "challenge_end_date" {
  type = string
}

variable "dry_run" {
  type    = bool
  default = false
}
