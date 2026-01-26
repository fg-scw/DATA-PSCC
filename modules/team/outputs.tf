output "project_name" {
  value = var.project_name
}

output "project_id" {
  value = module.project.project_id
}

output "pgw_ip" {
  value = module.infra.pgw_ip
}

output "instance_ip" {
  value = module.infra.instance_ip
}
