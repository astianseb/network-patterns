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



# module "vlan-attachment-1" {
#   source      = "./modules/net-interconnect-attachment-direct"
#   project_id  = var.dedicated_ic_project_id
#   region      = "us-west2"
#   router_name = "ic-router-1"
#   router_config = {
#     description = ""
#     asn         = local.asn
#     advertise_config = {
#       groups = ["ALL_SUBNETS"]
#       ip_ranges = {
#         "199.36.153.8/30" = "custom"
#       }
#       mode = "CUSTOM"
#     }
#   }
#   router_network = google_compute_network.vpc_internal_custom.id
#   name           = "vlan-${local.vlan_id}-1"
#   interconnect   = "https://www.googleapis.com/compute/v1/projects/cso-lab-management/global/interconnects/cso-lab-interconnect-1"

#   config = {
#     description   = ""
#     vlan_id       = local.vlan_id
#     bandwidth     = "BPS_10G"
#     admin_enabled = true
#     mtu           = 1440
#   }
#   peer = {
#       ip_address = local.bgp_ip_address_1
#       asn        = 65418
#   }
#   bgp = {
#       session_range             = local.bgp_session_range_1
#       advertised_route_priority = 0
#       candidate_ip_ranges       = [local.bgp_candidate_ip_ranges_1]
#   }
# }

# module "vlan-attachment-2" {
#   source      = "./modules/net-interconnect-attachment-direct"
#   project_id  = var.dedicated_ic_project_id
#   region      = "us-west2"
#   router_name = "ic-router-2"
#   router_config = {
#     description = ""
#     asn         = local.asn
#     advertise_config = {
#       groups = ["ALL_SUBNETS"]
#       ip_ranges = {
#         "199.36.153.8/30" = "custom"
#       }
#       mode = "CUSTOM"
#     }

#   }
#   router_network = google_compute_network.vpc_internal_custom.id
#   name           = "vlan-${local.vlan_id}-2"

#   interconnect   = "https://www.googleapis.com/compute/v1/projects/cso-lab-management/global/interconnects/cso-lab-interconnect-2"

#   config = {
#     description   = ""
#     vlan_id       = local.vlan_id
#     bandwidth     = "BPS_10G"
#     admin_enabled = true
#     mtu           = 1440
#   }
#   peer = {
#     ip_address = local.bgp_ip_address_2
#     asn        = 65418
#   }
#   bgp = {
#     session_range             = local.bgp_session_range_2
#     advertised_route_priority = 0
#     candidate_ip_ranges       = [local.bgp_candidate_ip_ranges_2]
#   }
# }





# module "vm_a" {
#   source        = "./modules/compute-vm"
#   project_id    = var.dedicated_ic_project_id
#   zone          = "us-west2-a"
#   name          = "vm-a"
#    options = {
#     allow_stopping_for_update = true
#     deletion_protection       = false
#     spot                      = true
#     termination_action        = "STOP"    
#   }
#   network_interfaces = [{
#     network    = google_compute_network.vpc_internal_custom.self_link
#     subnetwork = google_compute_subnetwork.subnet_a.self_link
#     nat        = false
#     addresses  = null
#   }]
#   service_account_create = true
#   metadata = {
#     enable-oslogin = true
#   }
#   tags = [
#       "bastion",
#       "internet-egress"
#   ]
# }

# resource "google_compute_firewall" "vm_a" {
#   name    = "bastion-allow-ssh"
#   network = google_compute_network.vpc_internal_custom.self_link

#   allow {
#     protocol = "icmp"
#   }

#   allow {
#     protocol = "tcp"
#     ports    = ["22"]
#   }

#   source_tags = ["bastion"]
# }

