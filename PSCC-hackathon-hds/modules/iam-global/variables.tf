variable "organization_id" {
  description = "Scaleway Organization ID"
  type        = string
}

variable "region" {
  description = "Scaleway region"
  type        = string
}

variable "zone" {
  description = "Scaleway zone"
  type        = string
}

variable "teams" {
  description = "Map of participating teams"
  type = map(object({
    name    = string
    members = list(string)
  }))
}

variable "admins" {
  description = "Admin configuration"
  type = object({
    name    = string
    members = list(string)
  })
}

variable "evaluators" {
  description = "Evaluators configuration"
  type = object({
    name    = string
    members = list(string)
  })
}

variable "data_providers" {
  description = "Data providers configuration"
  type = map(object({
    name    = string
    members = list(string)
  }))
}

variable "admin_project_id" {
  description = "Admin project ID"
  type        = string
}

variable "team_project_ids" {
  description = "Map of team keys to project IDs"
  type        = map(string)
}

variable "enable_console_access" {
  description = "Enable console access for users"
  type        = bool
  default     = false
}

variable "challenge_end_date" {
  description = "Challenge end date (for API key expiration)"
  type        = string
}

variable "dry_run" {
  description = "Skip user creation (no invitations sent)"
  type        = bool
  default     = false
}
