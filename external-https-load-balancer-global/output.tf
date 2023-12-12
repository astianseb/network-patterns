output "login_producer_siege_host_region_a" {
  
  value = <<EOT
    gcloud beta compute ssh --zone "${google_compute_instance.siege_host_region_a.zone}" "${google_compute_instance.siege_host_region_a.name}" --tunnel-through-iap --project "${google_project.producer.project_id}" 
EOT
}

output "login_producer_siege_host_region_b" {
  
  value = <<EOT
    gcloud beta compute ssh --zone "${google_compute_instance.siege_host_region_b.zone}" "${google_compute_instance.siege_host_region_b.name}" --tunnel-through-iap --project "${google_project.producer.project_id}" 
EOT
}

output "producer_endpoint" {
    value = google_compute_global_forwarding_rule.app_forwarding_rule.ip_address
}