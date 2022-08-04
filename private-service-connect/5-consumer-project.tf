resource "google_project" "consumer" {
  name                = "${var.consumer_project_name}-${random_id.id.hex}"
  project_id          = "${var.consumer_project_name}-${random_id.id.hex}"
  billing_account     = var.billing_account
  folder_id           = try(var.folder_id, false)
  auto_create_network = false
}

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

####### FIREWALL

resource "google_compute_firewall" "consumer_fw_allow_internal" {
  name      = "allow-internal"
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
  name      = "allow-ssh"
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


