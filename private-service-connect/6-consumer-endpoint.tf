resource "google_compute_address" "psc_ilb_consumer_address" {
  name   = "psc-ilb-consumer-address"
  region = var.region
  project = google_project.consumer.project_id

  subnetwork   = google_compute_subnetwork.consumer_sb_subnet_a.self_link
  address_type = "INTERNAL"
}


resource "google_compute_forwarding_rule" "psc_ilb_consumer" {
  name   = "psc-ilb-consumer-forwarding-rule"
  region = var.region
  project = google_project.consumer.project_id


  target                = google_compute_service_attachment.psc_ilb_service_attachment.id
  load_balancing_scheme = "" # need to override EXTERNAL default when target is a service attachment
  network               = google_compute_network.consumer_vpc_network.id
  ip_address            = google_compute_address.psc_ilb_consumer_address.id
}