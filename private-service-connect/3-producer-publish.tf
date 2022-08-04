resource "google_compute_subnetwork" "sb_subnet_psc" {
  name          = "subnet-psc"
  project       = google_project.producer.project_id
  ip_cidr_range = "10.10.100.0/24"
  network       = google_compute_network.producer_vpc_network.id
  purpose       =  "PRIVATE_SERVICE_CONNECT"

}

resource "google_compute_service_attachment" "psc_ilb_service_attachment" {
  name        = "my-psc-ilb"
  region      = var.region
  project     = google_project.producer.project_id
  description = "A service attachment configured with Terraform"

 # domain_names             = ["gcp.tfacc.hashicorptest.com."]
  enable_proxy_protocol    = false
  connection_preference    = "ACCEPT_AUTOMATIC"
  nat_subnets              = [google_compute_subnetwork.sb_subnet_psc.id]
  target_service           = google_compute_forwarding_rule.app_forwarding_rule.id
}

