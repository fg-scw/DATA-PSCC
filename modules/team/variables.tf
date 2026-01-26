variable "permissions_set" {
  type = set(string)
  default = [
    "AllProductsFullAccess",
  ]
}

variable "prefix" {
  type    = string
  default = "hackathon"
}
