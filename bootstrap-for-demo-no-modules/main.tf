locals {
  zone-b = "${var.region}-b"
  zone-c = "${var.region}-c"
  subnets = [
    {
      name          = "sg-subnet-a",
      ip_cidr_range = "10.1.10.0/24",
      region        = var.region
    },
    {
      name          = "sg-subnet-b",
      ip_cidr_range = "10.1.11.0/24",
      region        = var.region
    }
  ]
}


resource "random_id" "project_id" {
  byte_length = 4
}

resource "google_project" "project" {
  org_id              = var.parent.parent_type == "organizations" ? var.parent.parent_id : null
  folder_id           = var.parent.parent_type == "folders" ? var.parent.parent_id : null
  project_id          = "${var.project_name}-${random_id.project_id.hex}"
  name                = "${var.project_name}-${random_id.project_id.hex}"
  billing_account     = var.billing_account
  auto_create_network = false
}

resource "google_project_service" "project_services" {
  for_each = toset([
    "compute.googleapis.com",
    "iap.googleapis.com"
  ])
  project = google_project.project.project_id
  service = each.value
}

resource "google_compute_network" "network" {
  project                 = google_project.project.project_id
  name                    = "sg-custom-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  for_each      = { for index, subnet in local.subnets : subnet.name => subnet }
  project       = google_project.project.project_id
  network       = google_compute_network.network.name
  region        = each.value.region
  name          = each.value.name
  ip_cidr_range = each.value.ip_cidr_range
}

resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  project = google_project.project.project_id
  network = google_compute_network.network.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = [for index, subnet in local.subnets : subnet.ip_cidr_range]
}


resource "google_compute_firewall" "allow_iap" {
  name    = "allow-iap"
  project = google_project.project.project_id
  network = google_compute_network.network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
}

resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  project = google_project.project.project_id
  region  = var.region
  network = google_compute_network.network.name
  bgp {
    asn = "65001"
  }
}

resource "google_compute_router_nat" "nat" {
  project                            = google_project.project.project_id
  region                             = var.region
  name                               = "nat"
  router                             = google_compute_router.nat_router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_instance" "vm_a" {
  name         = "vm-a"
  project      = google_project.project.project_id
  machine_type = "e2-medium"
  zone         = local.zone-b

  tags = ["foo", "bar"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      labels = {
        my_label = "value"
      }
    }
  }

  network_interface {
    network    = google_compute_network.network.name
    subnetwork = google_compute_subnetwork.subnetwork["sg-subnet-a"].self_link
  }

  scheduling {
    preemptible       = true
    automatic_restart = false
  }

  #   access_config {
  #     // Ephemeral public IP
  #   }
  # }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }

  metadata = {
    enable-oslogin = true
  }

  metadata_startup_script = "echo hi > /test.txt"

}


