output "project_id" {
  description = "Admin project ID"
  value       = scaleway_account_project.admin.id
}

output "project_name" {
  description = "Admin project name"
  value       = scaleway_account_project.admin.name
}

output "zone1_bucket_name" {
  description = "Zone 1 bucket name"
  value       = scaleway_object_bucket.zone1.name
}

output "zone1_bucket_endpoint" {
  description = "Zone 1 bucket endpoint"
  value       = scaleway_object_bucket.zone1.endpoint
}

output "zone2_bucket_name" {
  description = "Zone 2 bucket name"
  value       = scaleway_object_bucket.zone2.name
}

output "zone2_bucket_endpoint" {
  description = "Zone 2 bucket endpoint"
  value       = scaleway_object_bucket.zone2.endpoint
}

output "livrables_bucket_name" {
  description = "Livrables bucket name"
  value       = scaleway_object_bucket.livrables.name
}

output "livrables_bucket_endpoint" {
  description = "Livrables bucket endpoint"
  value       = scaleway_object_bucket.livrables.endpoint
}

output "access_logs_bucket_name" {
  description = "Access logs bucket name"
  value       = var.enable_access_logs ? scaleway_object_bucket.access_logs[0].name : null
}

output "zone1_encryption_key_base64" {
  description = "Zone 1 SSE-C encryption key (base64)"
  value       = random_bytes.zone1_encryption_key.base64
  sensitive   = true
}

output "zone2_encryption_key_base64" {
  description = "Zone 2 SSE-C encryption key (base64)"
  value       = random_bytes.zone2_encryption_key.base64
  sensitive   = true
}

output "livrables_encryption_key_base64" {
  description = "Livrables SSE-C encryption key (base64)"
  value       = random_bytes.livrables_encryption_key.base64
  sensitive   = true
}

output "cockpit_metrics_url" {
  description = "Cockpit metrics push URL"
  value       = var.enable_cockpit ? scaleway_cockpit_source.admin_metrics[0].push_url : null
}

output "cockpit_logs_url" {
  description = "Cockpit logs push URL"
  value       = var.enable_cockpit ? scaleway_cockpit_source.admin_logs[0].push_url : null
}
