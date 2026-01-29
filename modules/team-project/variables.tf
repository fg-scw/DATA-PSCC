variable "project_prefix" {
  type = string
}

variable "team_name" {
  type = string
}

variable "team_members" {
  type    = list(string)
  default = []
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "private_network_cidr" {
  type = string
}

variable "bastion_instance_type" {
  type    = string
  default = "PRO2-XS"
}

variable "bastion_image" {
  type    = string
  default = "ubuntu_jammy"
}

variable "bastion_ssh_port" {
  type    = number
  default = 22
}

variable "gpu_instance_type" {
  type    = string
  default = "L40S-1-48G"
}

variable "gpu_image" {
  type    = string
  default = "ubuntu_jammy_gpu_os_12"
}

variable "gpu_root_volume_size_gb" {
  type    = number
  default = 200
}

variable "gpu_root_volume_iops" {
  type    = number
  default = 15000
}

variable "zone1_bucket_name" {
  type = string
}

variable "zone1_bucket_endpoint" {
  type = string
}

variable "livrables_bucket_name" {
  type = string
}

variable "livrables_bucket_endpoint" {
  type = string
}

variable "zone1_encryption_key_base64" {
  type      = string
  sensitive = true
}

variable "challenge_end_date" {
  type = string
}

variable "livrables_encryption_key_base64" {
  type      = string
  sensitive = true
}