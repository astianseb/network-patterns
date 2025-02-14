locals {
  zone-a = "${var.region_a}-b"
  zone-b = "${var.region_b}-c"
}

provider "google" {
}

resource "random_id" "id" {
  byte_length = 4
  prefix      = "sg"
}


############ PROJECT ###############

# resource "google_project" "producer" {
#   org_id              = var.parent.parent_type == "organizations" ? var.parent.parent_id : null
#   folder_id           = var.parent.parent_type == "folders" ? var.parent.parent_id : null
#   name                = "${var.producer_project_name}-${random_id.id.hex}"
#   project_id          = "${var.producer_project_name}-${random_id.id.hex}"
#   billing_account     = var.billing_account
#   auto_create_network = false
# }

data "google_project" "producer" {
    project_id = var.sg_project_id
}


resource "google_project_service" "producer_service" {
  for_each = toset([
    "compute.googleapis.com",
    "servicedirectory.googleapis.com",
    "dns.googleapis.com"
  ])

  service            = each.key
  project            = data.google_project.producer.project_id
  disable_on_destroy = false
}

####### VPC NETWORK

resource "google_compute_network" "producer_vpc_network" {
  name                    = "${var.sg_prefix}-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460
  project                 = data.google_project.producer.project_id
}


####### VPC SUBNETS

resource "google_compute_subnetwork" "producer_sb_subnet_a" {
  name          = "subnet-a"
  project       = data.google_project.producer.project_id
  ip_cidr_range = "10.10.20.0/24"
  network       = google_compute_network.producer_vpc_network.id
  region        = var.region_a
}

resource "google_compute_subnetwork" "producer_sb_subnet_b" {
  name          = "subnet-b"
  project       = data.google_project.producer.project_id
  ip_cidr_range = "10.10.40.0/24"
  network       = google_compute_network.producer_vpc_network.id
  region        = var.region_b
}

resource "google_compute_subnetwork" "producer_proxy" {
  name          = "l7-proxy-subnet"
  project       = data.google_project.producer.project_id
  region        = var.region_a
  ip_cidr_range = "10.10.200.0/24"
  network       = google_compute_network.producer_vpc_network.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"


}

####### FIREWALL

resource "google_compute_firewall" "producer_fw-allow-internal" {
  name      = "sg-allow-internal"
  project   = data.google_project.producer.project_id
  network   = google_compute_network.producer_vpc_network.name
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
    google_compute_subnetwork.producer_sb_subnet_a.ip_cidr_range,
    google_compute_subnetwork.producer_sb_subnet_b.ip_cidr_range]
}

resource "google_compute_firewall" "producer_fw_allow_ssh" {
  name      = "sg-allow-ssh"
  project   = data.google_project.producer.project_id
  network   = google_compute_network.producer_vpc_network.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "producer_fw_app_allow_http" {
  name      = "sg-app-allow-http"
  project   = data.google_project.producer.project_id
  network   = google_compute_network.producer_vpc_network.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["80", "8080"]
  }
  target_tags   = ["lb-backend"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "producer_fw_app_allow_health_check" {
  name      = "sg-app-allow-health-check"
  project   = data.google_project.producer.project_id
  network   = google_compute_network.producer_vpc_network.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }
  target_tags   = ["lb-backend"]
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

#### NAT

resource "google_compute_router" "producer_router_region_a" {
  name    = "nat-router-region-a"
  project = data.google_project.producer.project_id
  network = google_compute_network.producer_vpc_network.id
  region  = var.region_a

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "producer_nat_region_a" {
  name                               = "my-router-nat-region-a"
  project                            = data.google_project.producer.project_id
  router                             = google_compute_router.producer_router_region_a.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  region                             = var.region_a

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_router" "producer_router_region_b" {
  name    = "nat-router-region-b"
  project = data.google_project.producer.project_id
  network = google_compute_network.producer_vpc_network.id
  region  = var.region_b

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "producer_nat_region_b" {
  name                               = "my-router-nat-region-b"
  project                            = data.google_project.producer.project_id
  router                             = google_compute_router.producer_router_region_b.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  region                             = var.region_b

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}



###################### HTTPS Global LB #####################

# Self-signed regional SSL certificate for testing
resource "tls_private_key" "producer" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "producer" {
  private_key_pem = tls_private_key.producer.private_key_pem

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

  dns_names = ["sg-test-producer.com"]

  subject {
    common_name  = "sg-test-producer.com"
    organization = "SG Test Producer"
  }
}

resource "google_compute_ssl_certificate" "producer" {
  project     = data.google_project.producer.project_id
  name_prefix = "${var.sg_prefix}-cert-"
  private_key = tls_private_key.producer.private_key_pem
  certificate = tls_self_signed_cert.producer.cert_pem
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_health_check" "tcp_health_check" {
  name               = "${var.sg_prefix}-tcp-hc"
  project            = data.google_project.producer.project_id
  timeout_sec        = 1
  check_interval_sec = 1


  tcp_health_check {
    port = "80"
  }
}

// ------------- Instance Group A
resource "google_compute_instance_template" "tmpl_instance_group_1" {
  name                 = "${var.sg_prefix}-ig-1"
  project              = data.google_project.producer.project_id
  description          = "SG instance group of non-preemptible hosts"
  instance_description = "description assigned to instances"
  machine_type         = "e2-medium"
  can_ip_forward       = false
  tags                 = ["lb-backend"]
  region               = var.region_a 

  scheduling {
    preemptible       = false
    automatic_restart = false

  }
  
  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }

  // Create a new boot disk from an image
  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network            = google_compute_network.producer_vpc_network.name
    subnetwork         = google_compute_subnetwork.producer_sb_subnet_a.name
    subnetwork_project = data.google_project.producer.project_id
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    startup-script-url = "https://raw.githubusercontent.com/astianseb/sg-helper-scripts/refs/heads/main/startup.sh"
#    startup-script-url = "gs://cloud-training/gcpnet/ilb/startup.sh"
  }
}

#MIG-a
resource "google_compute_instance_group_manager" "grp_instance_group_1" {
  name               = "${var.sg_prefix}-igm-1"
  project            = data.google_project.producer.project_id
  base_instance_name = "${var.sg_prefix}-mig-a"
  zone               = local.zone-a
  version {
    instance_template = google_compute_instance_template.tmpl_instance_group_1.id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.tcp_health_check.id
    initial_delay_sec = 300
  }
  named_port {
    name = "${var.sg_prefix}-https"
    port = 443
  }
}

resource "google_compute_autoscaler" "obj_my_autoscaler_a" {
  name    = "${var.sg_prefix}-autoscaler-a"
  project = data.google_project.producer.project_id
  zone    = local.zone-a
  target  = google_compute_instance_group_manager.grp_instance_group_1.id

  autoscaling_policy {
    max_replicas    = 2
    min_replicas    = 1
    cooldown_period = 45

    cpu_utilization {
      target = 0.8
    }
  }
}


//----------------Instance Group B

resource "google_compute_instance_template" "tmpl_instance_group_2" {
  name                 = "${var.sg_prefix}-ig-2"
  project              = data.google_project.producer.project_id
  description          = "SG instance group of non preemptible hosts"
  instance_description = "description assigned to instances"
  machine_type         = "e2-medium"
  can_ip_forward       = false
  tags                 = ["lb-backend"]
  region               = var.region_b

  scheduling {
    preemptible       = false
    automatic_restart = false

  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network            = google_compute_network.producer_vpc_network.name
    subnetwork         = google_compute_subnetwork.producer_sb_subnet_b.name
    subnetwork_project = data.google_project.producer.project_id
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    startup-script-url = "https://raw.githubusercontent.com/astianseb/sg-helper-scripts/refs/heads/main/startup.sh"
#    startup-script-url = "gs://cloud-training/gcpnet/ilb/startup.sh"
  }
}

resource "google_compute_instance_group_manager" "grp_instance_group_2" {
  name               = "${var.sg_prefix}-igm-2"
  project            = data.google_project.producer.project_id
  base_instance_name = "${var.sg_prefix}-mig-b"
  zone               = local.zone-b
  
  version {
    instance_template = google_compute_instance_template.tmpl_instance_group_2.id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.tcp_health_check.id
    initial_delay_sec = 300
  }
  named_port {
    name = "${var.sg_prefix}-https"
    port = 443
  }
}

resource "google_compute_autoscaler" "obj_my_autoscaler_b" {
  name    = "${var.sg_prefix}-autoscaler-b"
  project = data.google_project.producer.project_id
  zone    = local.zone-b
  target  = google_compute_instance_group_manager.grp_instance_group_2.id

  autoscaling_policy {
    max_replicas    = 2
    min_replicas    = 1
    cooldown_period = 45

    cpu_utilization {
      target = 0.8
    }
  }
}



# forwarding rule
resource "google_compute_global_forwarding_rule" "app_forwarding_rule" {
  name                  = "${var.sg_prefix}-fr"
  provider              = google-beta
  project               = data.google_project.producer.project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.producer.id
 # ip_address            = google_compute_address.default.id
}

# http proxy
resource "google_compute_target_https_proxy" "producer" {
  name     = "${var.sg_prefix}-https-proxy"
  provider = google-beta
  project  = data.google_project.producer.project_id
  url_map  = google_compute_url_map.producer.id
  
  ssl_certificates = [google_compute_ssl_certificate.producer.self_link]

}

# url map
resource "google_compute_url_map" "producer" {
  name            = "${var.sg_prefix}-url-map"
  provider        = google-beta
  project         = data.google_project.producer.project_id
  default_service = google_compute_backend_service.app_backend.id
}


# HTTP regional load balancer (envoy based)
resource "google_compute_backend_service" "app_backend" {
  name                     = "${var.sg_prefix}-app-bs"
  provider                 = google-beta
  project                  = data.google_project.producer.project_id
#  protocol                 = "HTTP"
#  port_name                = "my-port"
  protocol                 = "HTTPS"
  port_name                = "${var.sg_prefix}-https"
  load_balancing_scheme    = "EXTERNAL_MANAGED"
  timeout_sec              = 10
  health_checks            = [google_compute_health_check.tcp_health_check.id]
  backend {
    group           = google_compute_instance_group_manager.grp_instance_group_1.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
  backend {
    group           = google_compute_instance_group_manager.grp_instance_group_2.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}



############### SIEGE HOST #####################

# Instance to host siege (testing tool for LB)
# usage: siege -i --concurrent=50 http://<lb-ip>
#

resource "google_compute_instance" "siege_host_region_a" {
  name         = "${var.sg_prefix}-siege-reg-a"
  machine_type = "e2-medium"
  zone         = local.zone-a
  project      = data.google_project.producer.project_id

  tags = ["siege"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.producer_vpc_network.name
    subnetwork = google_compute_subnetwork.producer_sb_subnet_a.self_link
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


resource "google_compute_instance" "siege_host_region_b" {
  name         = "${var.sg_prefix}-siege-reg-b"
  machine_type = "e2-medium"
  zone         = local.zone-b
  project      = data.google_project.producer.project_id

  tags = ["siege"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.producer_vpc_network.name
    subnetwork = google_compute_subnetwork.producer_sb_subnet_b.self_link
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