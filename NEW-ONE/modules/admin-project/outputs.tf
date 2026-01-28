output "project_id" {
  value = scaleway_account_project.admin.id
}

output "project_name" {
  value = scaleway_account_project.admin.name
}

output "zone1_bucket_name" {
  value = scaleway_object_bucket.zone1.name
}

output "zone1_bucket_endpoint" {
  value = scaleway_object_bucket.zone1.endpoint
}

output "zone2_bucket_name" {
  value = scaleway_object_bucket.zone2.name
}

output "zone2_bucket_endpoint" {
  value = scaleway_object_bucket.zone2.endpoint
}

output "livrables_bucket_name" {
  value = scaleway_object_bucket.livrables.name
}

output "livrables_bucket_endpoint" {
  value = scaleway_object_bucket.livrables.endpoint
}

output "zone1_encryption_key_base64" {
  value     = random_bytes.zone1_encryption_key.base64
  sensitive = true
}

output "zone2_encryption_key_base64" {
  value     = random_bytes.zone2_encryption_key.base64
  sensitive = true
}

output "livrables_encryption_key_base64" {
  value     = random_bytes.livrables_encryption_key.base64
  sensitive = true
}
