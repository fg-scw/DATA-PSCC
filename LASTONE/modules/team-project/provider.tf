terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
    }
    tls = {
      source = "hashicorp/tls"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}
