resource "google_project" "consumer" {
  name                = "${var.consumer_project_name}-${random_id.id.hex}"
  project_id          = "${var.consumer_project_name}-${random_id.id.hex}"
  billing_account     = var.billing_account
  folder_id           = try(var.folder_id, false)
  auto_create_network = false
}


# data "google_project" "consumer" {
#     project_id = var.consumer_project_id
# }

resource "google_project_service" "consumer_service" {
  for_each = toset([
    "compute.googleapis.com",
    "servicedirectory.googleapis.com",
    "dns.googleapis.com"
  ])

  service            = each.key
  project            = google_project.consumer.project_id
  disable_on_destroy = false
}

####### VPC NETWORK

resource "google_compute_network" "consumer_vpc_network" {
  name                    = "consumer-network"
  auto_create_subnetworks = false
  mtu                     = 1460
  project                 = google_project.consumer.project_id
}


####### VPC SUBNETS

resource "google_compute_subnetwork" "consumer_sb_subnet_a" {
  name          = "subnet-a"
  project       = google_project.consumer.project_id
  ip_cidr_range = "192.168.10.0/24"
  network       = google_compute_network.consumer_vpc_network.id
}


resource "google_compute_subnetwork" "psc_subnet" {
  name          = "proxy-subnet"
  project       = google_project.consumer.project_id
  region        = var.region
  ip_cidr_range = "10.10.100.0/24"
  network       = google_compute_network.consumer_vpc_network.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}


####### FIREWALL

resource "google_compute_firewall" "consumer_fw_allow_internal" {
  name      = "sg-allow-internal"
  project   = google_project.consumer.project_id
  network   = google_compute_network.consumer_vpc_network.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [
      google_compute_subnetwork.consumer_sb_subnet_a.ip_cidr_range]
}

resource "google_compute_firewall" "consumer_fw_allow_ssh" {
  name      = "sg-allow-ssh"
  project   = google_project.consumer.project_id
  network   = google_compute_network.consumer_vpc_network.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}


#### NAT

resource "google_compute_router" "consumer_router" {
  name    = "nat-router"
  project = google_project.consumer.project_id
  network = google_compute_network.consumer_vpc_network.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "consumer_nat" {
  name                               = "my-router-nat"
  project                            = google_project.consumer.project_id
  router                             = google_compute_router.consumer_router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}


################### HTTPS BACKEND #######################

# Self-signed regional SSL certificate for testing
resource "tls_private_key" "consumer" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "consumer" {
  private_key_pem = tls_private_key.consumer.private_key_pem

  # Certificate expires after 48 hours.
  validity_period_hours = 48

  # Generate a new certificate if Terraform is run within three
  # hours of the certificate's expiration time.
  early_renewal_hours = 3

  # Reasonable set of uses for a server SSL certificate.
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = ["sg-test-consumer.com"]

  subject {
    common_name  = "sg-test-consumer.com"
    organization = "SG Test Consumer"
  }
}

resource "google_compute_region_ssl_certificate" "consumer" {
  project     = google_project.consumer.project_id
  name_prefix = "my-certificate-"
  private_key = tls_private_key.consumer.private_key_pem
  certificate = tls_self_signed_cert.consumer.cert_pem
  region      = var.region
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_network_endpoint_group" "psc_neg_service_attachment" {
  name                  = "psc-neg"
  project               = google_project.consumer.project_id
  region                = var.region
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = google_compute_service_attachment.psc_service_attachment.id
  
  network    = google_compute_network.consumer_vpc_network.name
  subnetwork = google_compute_subnetwork.consumer_sb_subnet_a.self_link
}


resource "google_compute_region_backend_service" "sg_psc_backend" {
  name                            = "sg-psc-backend"
  project                         = google_project.consumer.project_id
  connection_draining_timeout_sec = 0
  load_balancing_scheme           = "INTERNAL_MANAGED"
  port_name                       = "my-https"
  protocol                        = "HTTPS"
  region                          = var.region
  session_affinity                = "NONE"
  timeout_sec                     = 30
  
  backend {
    group           = google_compute_region_network_endpoint_group.psc_neg_service_attachment.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}


resource "google_compute_region_url_map" "sg_lb" {
  name            = "sg-lb"
  project         = google_project.consumer.project_id
  region          = var.region
  default_service = google_compute_region_backend_service.sg_psc_backend.self_link
}

resource "google_compute_region_target_https_proxy" "sg_lb_target_proxy" {
  name    = "sg-lb-target-proxy"
  project = google_project.consumer.project_id
  region  = var.region
  url_map = google_compute_region_url_map.sg_lb.self_link
  
  ssl_certificates = [google_compute_region_ssl_certificate.consumer.self_link]
}


# reserved IP address
resource "google_compute_address" "psc_ilb_consumer_address" {
  provider     = google-beta
  region       = var.region
  project      = google_project.consumer.project_id
  name         = "consumer-ip"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.consumer_sb_subnet_a.id


}

resource "google_compute_forwarding_rule" "sg_lb_forwarding_rule" {
  name                  = "sg-lb-forwarding-rule"
  project = google_project.consumer.project_id
 # allow_global_access   = true
  ip_address            = google_compute_address.psc_ilb_consumer_address.id
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  network               = google_compute_network.consumer_vpc_network.name
  port_range            = "443"
  region                = var.region
  subnetwork            = google_compute_subnetwork.consumer_sb_subnet_a.self_link
  target                = google_compute_region_target_https_proxy.sg_lb_target_proxy.self_link
}


######################## SIEGE HOST ################

# Instance to host siege (testing tool for LB)
# usage: siege -i --concurrent=50 http://<lb-ip>


resource "google_compute_instance" "consumer_siege_host" {
  name         = "consumer-siege-host"
  machine_type = "e2-medium"
  zone         = local.zone-a
  project      = google_project.consumer.project_id

  tags = ["siege"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network    = google_compute_network.consumer_vpc_network.name
    subnetwork = google_compute_subnetwork.consumer_sb_subnet_a.self_link
  }

  scheduling {
    preemptible       = true
    automatic_restart = false
  }
  
  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }

  metadata = {
    enable-oslogin = true
  }


  metadata_startup_script = <<-EOF1
      #! /bin/bash
      set -euo pipefail

      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y siege
     EOF1

}