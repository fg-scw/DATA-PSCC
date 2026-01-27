terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = ">= 2.40.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.10.0"
    }
  }
}

provider "scaleway" {
  region  = var.region
  zone    = var.zone
  profile = var.scw_profile
}
