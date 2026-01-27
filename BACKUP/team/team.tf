module "project" {
  source          = "./modules/project"
  project_name    = var.project_name
  members         = var.members
  permissions_set = var.permissions_set
  bucket_prefix   = var.prefix
  org_id          = var.org_id
  zone_id         = var.zone_id
}

module "infra" {
  source          = "./modules/infra"
  project_id      = module.project.project_id
  resource_prefix = var.prefix
  ssh_keys_hash   = module.project.ssh_keys_hash
  depends_on      = [module.project]
}
