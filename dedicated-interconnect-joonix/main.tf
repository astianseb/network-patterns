locals {
  asn                       = "6500${var.deploy_number}"
  vlan_id                   = "60${var.deploy_number}"
  bgp_candidate_ip_ranges_1 = "169.254.6${var.deploy_number}.0/29"
  bgp_ip_address_1          = "169.254.6${var.deploy_number}.2"
  bgp_session_range_1       = "169.254.6${var.deploy_number}.1/29" 
  bgp_candidate_ip_ranges_2 = "169.254.6${var.deploy_number}.8/29"
  bgp_ip_address_2          = "169.254.6${var.deploy_number}.10"
  bgp_session_range_2       = "169.254.6${var.deploy_number}.9/29" 
}



resource "random_id" "project_id" {
  byte_length = 4
}

data "google_project" "dedicated_ic_project" {
  project_id   = var.dedicated_ic_project_id
}

resource "google_project_service" "project_services" {
  project = var.dedicated_ic_project_id
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com"
  ])
  service = each.value
}


resource "google_compute_network" "vpc_internal_custom" {
  name       = "vpc-internal-custom"
  project    = var.dedicated_ic_project_id
}

resource "google_compute_subnetwork" "subnet_a" {
  name          = "subnet-a"
  project       = var.dedicated_ic_project_id
  region        = "us-west2"
  ip_cidr_range = "10.2.0.0/24"
  network       = google_compute_network.vpc_internal_custom.id
}

resource "google_compute_subnetwork" "subnet_b" {
  name          = "subnet-b"
  project       = var.dedicated_ic_project_id
  region        = "us-west2"
  ip_cidr_range = "10.2.16.0/24"
  network       = google_compute_network.vpc_internal_custom.id
}

resource "google_compute_router" "router_nat" {
  name    = "router-nat"
  region  = "us-west2"
  network = google_compute_network.vpc_internal_custom.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "cloud_nat" {
  name                               = "cloud-nat"
  region                             = "us-west2"
  router                             = google_compute_router.router_nat.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_router" "ic_router_1" {
  name    = "ic-router-1"
  region  = "us-west2"
  network = google_compute_network.vpc_internal_custom.name
  bgp {
    asn               = local.asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
    advertised_ip_ranges {
      range = "199.36.153.8/30"
    }
    advertised_ip_ranges {
      range = "6.7.0.0/16"
    }
  }
}


resource "google_compute_interconnect_attachment" "sg_attach_1" {
  name                     = "vlan-${local.vlan_id}-1"
  region                   = "us-west2"
  type                     = "DEDICATED"
  interconnect             = "https://www.googleapis.com/compute/v1/projects/cso-lab-management/global/interconnects/cso-lab-interconnect-1"
  router                   = google_compute_router.ic_router_1.id
  mtu                      = 1440
  bandwidth                = "BPS_1G"
  admin_enabled            = true
  vlan_tag8021q            = local.vlan_id
  description              = ""
  candidate_subnets        = [local.bgp_candidate_ip_ranges_1]

}

resource "google_compute_router_interface" "interface_1" {
  name                    = "interface-1"
  region                  = "us-west2"
  router                  = google_compute_router.ic_router_1.name
  ip_range                = local.bgp_session_range_1
  interconnect_attachment = google_compute_interconnect_attachment.sg_attach_1.name
}

resource "google_compute_router_peer" "sg_peer_1" {
  name                      = "sg-peer-1"
  region                    = "us-west2"
  router                    = google_compute_router.ic_router_1.name
  peer_ip_address           = local.bgp_ip_address_1
  peer_asn                  = 65418
  advertised_route_priority = 0
  interface                 = google_compute_router_interface.interface_1.name
}



resource "google_compute_router" "ic_router_2" {
  name    = "ic-router-2"
  region  = "us-west2"
  network = google_compute_network.vpc_internal_custom.name
  bgp {
    asn               = local.asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
    advertised_ip_ranges {
      range = "199.36.153.8/30"
    }
    advertised_ip_ranges {
      range = "6.7.0.0/16"
    }
  }
}


resource "google_compute_interconnect_attachment" "sg_attach_2" {
  name                     = "vlan-${local.vlan_id}-2"
  region                   = "us-west2"
  type                     = "DEDICATED"
  interconnect             = "https://www.googleapis.com/compute/v1/projects/cso-lab-management/global/interconnects/cso-lab-interconnect-2"
  router                   = google_compute_router.ic_router_2.id
  mtu                      = 1440
  bandwidth                = "BPS_1G"
  admin_enabled            = true
  vlan_tag8021q            = local.vlan_id
  description              = ""
  candidate_subnets        = [local.bgp_candidate_ip_ranges_2]

}

resource "google_compute_router_interface" "interface_2" {
  name                    = "interface-2"
  region                  = "us-west2"
  router                  = google_compute_router.ic_router_2.name
  ip_range                = local.bgp_session_range_2
  interconnect_attachment = google_compute_interconnect_attachment.sg_attach_2.name
}

resource "google_compute_router_peer" "sg_peer_2" {
  name                      = "sg-peer-2"
  region                    = "us-west2"
  router                    = google_compute_router.ic_router_2.name
  peer_ip_address           = local.bgp_ip_address_2
  peer_asn                  = 65418
  advertised_route_priority = 0
  interface                 = google_compute_router_interface.interface_2.name
}


resource "google_compute_instance" "vm_a" {
  name         = "vm-a"
  machine_type = "e2-medium"
  zone         = "us-west2-a"

  tags = ["bastion", "internet-egress"]

  boot_disk {
    initialize_params {
      image  = "debian-cloud/debian-11"
      labels = {
        my_label = "value"
      }
    }
  }

  network_interface {
    network    = google_compute_network.vpc_internal_custom.self_link
    subnetwork = google_compute_subnetwork.subnet_a.self_link

  }

  scheduling {
    preemptible       = true
    automatic_restart = false
  }

  metadata = {
    enable-oslogin = true
  }

  metadata_startup_script = "echo hi > /test.txt"

}


resource "google_compute_firewall" "vm_a" {
  name    = "vm-a-allow-ssh"
  network = google_compute_network.vpc_internal_custom.self_link

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_tags = ["bastion"]
}

