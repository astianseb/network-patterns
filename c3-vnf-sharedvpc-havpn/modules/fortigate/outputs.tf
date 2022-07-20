# Output
output "FortiGate-NATIP" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}
output "FortiGate-InstanceName" {
  value = google_compute_instance.default.name
}
output "FortiGate-Username" {
  value = "admin"
}
output "FortiGate-Password" {
  value = google_compute_instance.default.instance_id
}
output "FortiGAte-intIP" {
  value = google_compute_instance.default.network_interface.1.network_ip
}

output "FortiGate-extIP" {
  value = google_compute_instance.default.network_interface.0.network_ip
}