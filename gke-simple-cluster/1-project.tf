resource "google_project" "gke" {
  name                = "${var.gke_project_name}-${random_id.id.hex}"
  project_id          = "${var.gke_project_name}-${random_id.id.hex}"
  folder_id           = try(var.folder_id, false)
  billing_account     = var.billing_account
  auto_create_network = false
}

resource "google_project_service" "gke_service" {
  for_each = toset([
    "compute.googleapis.com",
    "servicedirectory.googleapis.com",
    "dns.googleapis.com",
    "container.googleapis.com"
  ])

  service            = each.key
  project            = google_project.gke.project_id
  disable_on_destroy = false
}

####### VPC NETWORK

resource "google_compute_network" "gke_vpc_network" {
  name                    = "gke-network"
  auto_create_subnetworks = false
  mtu                     = 1460
  project                 = google_project.gke.project_id
}


####### VPC SUBNETS

resource "google_compute_subnetwork" "gke_sb_subnet_a" {
  name          = "subnet-a"
  project       = google_project.gke.project_id
  region        = var.region
  ip_cidr_range = "10.10.20.0/24"
  network       = google_compute_network.gke_vpc_network.id
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "192.168.10.0/24"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "192.168.20.0/24"
  }
}

resource "google_compute_subnetwork" "gke_sb_subnet_b" {
  name          = "subnet-b"
  project       = google_project.gke.project_id
  region        = var.region
  ip_cidr_range = "10.10.40.0/24"
  network       = google_compute_network.gke_vpc_network.id
}

####### FIREWALL

resource "google_compute_firewall" "gke_fw-allow-internal" {
  name      = "allow-internal"
  project   = google_project.gke.project_id
  network   = google_compute_network.gke_vpc_network.name
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
    google_compute_subnetwork.gke_sb_subnet_a.ip_cidr_range,
    google_compute_subnetwork.gke_sb_subnet_b.ip_cidr_range]
}

resource "google_compute_firewall" "gke_fw_allow_ssh" {
  name      = "allow-ssh"
  project   = google_project.gke.project_id
  network   = google_compute_network.gke_vpc_network.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "gke_fw_app_allow_http" {
  name      = "app-allow-http"
  project   = google_project.gke.project_id
  network   = google_compute_network.gke_vpc_network.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["80", "8080"]
  }
  target_tags   = ["lb-backend"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "gke_fw_app_allow_health_check" {
  name      = "app-allow-health-check"
  project   = google_project.gke.project_id
  network   = google_compute_network.gke_vpc_network.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }
  target_tags   = ["lb-backend"]
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

#### NAT

resource "google_compute_router" "gke_router" {
  name    = "nat-router"
  project = google_project.gke.project_id
  network = google_compute_network.gke_vpc_network.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "gke_nat" {
  name                               = "my-router-nat"
  project                            = google_project.gke.project_id
  router                             = google_compute_router.gke_router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

module "bastion_vm" {
  source     = "./modules/compute-vm"
  project_id = google_project.gke.project_id
  zone       = local.zone-a
  name       = "bastion-vm-spot"
   options = {
    allow_stopping_for_update = true
    deletion_protection       = false
    spot                      = true
    termination_action        = "STOP"    
  }
  network_interfaces = [{
    network    = google_compute_network.gke_vpc_network.self_link
    subnetwork = google_compute_subnetwork.gke_sb_subnet_a.self_link
    nat        = false
    addresses  = null
  }]
  service_account_create = true
  metadata = {
    enable-oslogin = true
  }
}

