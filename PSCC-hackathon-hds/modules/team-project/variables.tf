variable "project_prefix" {
  description = "Prefix for project name"
  type        = string
}

variable "team_name" {
  description = "Team name"
  type        = string
}

variable "team_members" {
  description = "List of team member emails"
  type        = list(string)
  default     = []
}

variable "region" {
  description = "Scaleway region"
  type        = string
}

variable "zone" {
  description = "Scaleway zone"
  type        = string
}

variable "private_network_cidr" {
  description = "CIDR for the team's private network"
  type        = string
}

variable "bastion_instance_type" {
  description = "Instance type for bastion"
  type        = string
  default     = "PRO2-XS"
}

variable "bastion_image" {
  description = "Image for bastion instance"
  type        = string
  default     = "ubuntu_jammy"
}

variable "bastion_ssh_port" {
  description = "SSH port for bastion"
  type        = number
  default     = 22
}

variable "gpu_instance_type" {
  description = "Instance type for GPU"
  type        = string
  default     = "L40S-1-48G"
}

variable "gpu_image" {
  description = "Image for GPU instance"
  type        = string
  default     = "ubuntu_jammy_gpu_os_12"
}

variable "gpu_root_volume_size_gb" {
  description = "Root volume size for GPU in GB"
  type        = number
  default     = 200
}

variable "gpu_root_volume_iops" {
  description = "IOPS for GPU root volume"
  type        = number
  default     = 15000
}

variable "zone1_bucket_name" {
  description = "Name of Zone 1 bucket"
  type        = string
}

variable "livrables_bucket_name" {
  description = "Name of livrables bucket"
  type        = string
}

variable "zone1_encryption_key_base64" {
  description = "Zone 1 SSE-C encryption key (base64)"
  type        = string
  sensitive   = true
}

variable "challenge_end_date" {
  description = "Challenge end date"
  type        = string
}

variable "enable_cockpit" {
  description = "Enable Cockpit monitoring"
  type        = bool
  default     = true
}
