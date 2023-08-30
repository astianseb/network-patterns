
output "vm_a_ip" {
    value = google_compute_instance.vm_a.network_interface[0].network_ip
  
}

output "ssh_to_vm_a" {
  
  value = <<EOT
    gcloud beta compute ssh --zone "${local.zone-b}" "${google_compute_instance.vm_a.name}" --tunnel-through-iap --project "${google_project.project.name}" 
EOT
}

output "swg_ip" {
    value = google_network_services_gateway.default.addresses
}