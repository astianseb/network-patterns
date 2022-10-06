output "login_to_vm" {
  
  value = <<EOT
    gcloud beta compute ssh --zone "${var.region}-b" "${module.vm_a.instance.name}" --tunnel-through-iap --project "${module.project-authorized-compute.project_id}" 
EOT

}

output "authorized_compute_project_id" {
  value = module.project-authorized-compute.project_id
}

output "authorized_gcs_project_id" {
  value = module.project-authorized-gcs.project_id
}

output "notauthorized_gcs_project_id" {
  value = module.project-notauthorized-gcs.project_id
}

output "autorized_bucket_name" {
  value = module.bucket-a.name
}

output "notauthorized_bucket_name" {
  value = module.bucket-na.name
}
