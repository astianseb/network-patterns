# resource "google_project" "consumer" {
#   name                = "${var.consumer_project_name}-${random_id.id.hex}"
#   project_id          = "${var.consumer_project_name}-${random_id.id.hex}"
#   billing_account     = var.billing_account
#   folder_id           = try(var.folder_id, false)
#   auto_create_network = false
# }


data "google_project" "consumer" {
    project_id = var.consumer_project_id
}

# resource "google_project_service" "consumer_service" {
#   for_each = toset([
#     "compute.googleapis.com",
#     "servicedirectory.googleapis.com",
#     "dns.googleapis.com"
#   ])

#   service            = each.key
#   project            = google_project.consumer.project_id
#   disable_on_destroy = false
# }

####### VPC NETWORK

resource "google_compute_network" "consumer_vpc_network" {
  name                    = "consumer-network"
  auto_create_subnetworks = false
  mtu                     = 1460
  project                 = data.google_project.consumer.project_id
}


####### VPC SUBNETS

resource "google_compute_subnetwork" "consumer_sb_subnet_a" {
  name          = "subnet-a"
  project       = data.google_project.consumer.project_id
  ip_cidr_range = "192.168.10.0/24"
  network       = google_compute_network.consumer_vpc_network.id
}

####### FIREWALL

resource "google_compute_firewall" "consumer_fw_allow_internal" {
  name      = "sg-allow-internal"
  project   = data.google_project.consumer.project_id
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
  project   = data.google_project.consumer.project_id
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
  project = data.google_project.consumer.project_id
  network = google_compute_network.consumer_vpc_network.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "consumer_nat" {
  name                               = "my-router-nat"
  project                            = data.google_project.consumer.project_id
  router                             = google_compute_router.consumer_router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}


#########################  ENDPOINT #####################

resource "google_compute_address" "psc_ilb_consumer_address" {
  name   = "psc-ilb-consumer-address"
  region = var.region
  project = data.google_project.consumer.project_id

  subnetwork   = google_compute_subnetwork.consumer_sb_subnet_a.self_link
  address_type = "INTERNAL"
}


resource "google_compute_forwarding_rule" "psc_ilb_consumer" {
  name   = "psc-ilb-consumer-forwarding-rule"
  region = var.region
  project = data.google_project.consumer.project_id


  target                = google_compute_service_attachment.psc_ilb_service_attachment.id
  load_balancing_scheme = "" # need to override EXTERNAL default when target is a service attachment
  network               = google_compute_network.consumer_vpc_network.id
  ip_address            = google_compute_address.psc_ilb_consumer_address.id
}


######################### SIEGE HOST ################

# Instance to host siege (testing tool for LB)
# usage: siege -i --concurrent=50 http://<lb-ip>
#

resource "google_compute_instance" "consumer_siege_host" {
  name         = "consumer-siege-host"
  machine_type = "e2-medium"
  zone         = local.zone-a
  project      = data.google_project.consumer.project_id

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