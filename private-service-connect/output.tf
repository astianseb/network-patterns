output "login_producer_siege_host" {
  
  value = <<EOT
    gcloud beta compute ssh --zone "${google_compute_instance.producer_siege_host.zone}" "${google_compute_instance.producer_siege_host.name}" --tunnel-through-iap --project "${google_project.producer.project_id}" 
EOT
}

output "login_consumer_siege_host" {
  
  value = <<EOT
    gcloud beta compute ssh --zone "${google_compute_instance.consumer_siege_host.zone}" "${google_compute_instance.consumer_siege_host.name}" --tunnel-through-iap --project "${google_project.consumer.project_id}" 
EOT

}

output "consumer_endpoint" {
    value = google_compute_address.psc_ilb_consumer_address.address
}

output "producer_endpoint" {
    value = google_compute_forwarding_rule.app_forwarding_rule.ip_address
}