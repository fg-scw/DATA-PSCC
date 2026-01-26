module "teams" {
  for_each     = var.teams
  source       = "./modules/team"
  project_name = each.value.name
  members      = each.value.members
  org_id       = var.org_id
  zone_id      = var.zone_id
}
