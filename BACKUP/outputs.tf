output "access" {
  value = [for team in module.teams : format("Team %s access via 'ssh -J bastion@%s:61000 root@%s'", team.project_name, team.pgw_ip, team.instance_ip)]
}
