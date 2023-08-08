
# output "project_a_id" {
#   value = google_project.project["project_a"].project_id
# }

# output "project_b_id" {
#   value = google_project.project["project_b"].project_id
# }

# output "cloud_instance" {
#     value = google_compute_instance.cloud_instance.network_interface[0].network_ip

# }

# output "onprem_instance" {
#     value = google_compute_instance.onprem_instance.network_interface[0].network_ip

# }

# output "ssh_to_cloud_instance" {
  
#   value = <<EOT
#     gcloud beta compute ssh --zone "${local.region-a-zone-a}" "${google_compute_instance.cloud_instance.name}" --tunnel-through-iap --project "${google_project.project["project_a"].project_id}" 
# EOT
# }

# output "ssh_to_onprem_instance" {
  
#   value = <<EOT
#     gcloud beta compute ssh --zone "${local.region-b-zone-a}" "${google_compute_instance.onprem_instance.name}" --tunnel-through-iap --project "${google_project.project["project_b"].project_id}" 
# EOT
# }