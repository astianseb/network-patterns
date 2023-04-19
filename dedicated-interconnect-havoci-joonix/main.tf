locals {
  asn                       = "6500${var.deploy_number}"
  vlan_id                   = "60${var.deploy_number}"
  bgp_candidate_ip_ranges_1 = "169.254.6${var.deploy_number}.0/29"
  bgp_ip_address_1          = "169.254.6${var.deploy_number}.2"
  bgp_session_range_1       = "169.254.6${var.deploy_number}.1/29" 
  bgp_candidate_ip_ranges_2 = "169.254.6${var.deploy_number}.8/29"
  bgp_ip_address_2          = "169.254.6${var.deploy_number}.10"
  bgp_session_range_2       = "169.254.6${var.deploy_number}.9/29"
  vpn_router_asn            = "6510${var.deploy_number}"
  ext_vpn_gw_1_ip_1         = "192.25.67.3"
  ext_vpn_gw_1_ip_2         = "192.25.67.4"
  ext_vpn_gw_2_ip_1         = "192.25.68.5"
  ext_vpn_gw_2_ip_2         = "192.25.68.6"
  shared_secret             = "secretkey"
  vpn_bgp_1                 = "169.254.1.1/30"
  vpn_bgp_peer_1            = "169.254.1.2"
  vpn_bgp_2                 = "169.254.2.1/30"
  vpn_bgp_peer_2            = "169.254.2.2"
  vpn_bgp_3                 = "169.254.3.1/30"
  vpn_bgp_peer_3            = "169.254.3.2"
  vpn_bgp_4                 = "169.254.4.1/30"
  vpn_bgp_peer_4            = "169.254.4.2"
  vpn_peer_asn              = "65500"
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

# Optional: Reserve regional internal IP ranges to allocate to the HA VPN gateway
# interfaces. Reserve an internal range for each VLAN attachment.

resource "google_compute_address" "address_vpn_ia_1" {
  name          = "address-vpn-ia-1"
  region        = "us-west2"
  address_type  = "INTERNAL"
  purpose       = "IPSEC_INTERCONNECT"
  address       = "10.3.0.240"
  prefix_length = 29 # Allows you to reserve up to 8 IP addresses
  network       = google_compute_network.vpc_internal_custom.self_link
}

resource "google_compute_address" "address_vpn_ia_2" {
  name          = "address-vpn-ia-2"
  region        = "us-west2"
  address_type  = "INTERNAL"
  purpose       = "IPSEC_INTERCONNECT"
  address       = "10.3.0.248"
  prefix_length = 29 # Allows you to reserve up to 8 IP addresses
  network       = google_compute_network.vpc_internal_custom.self_link
}



#
# Stage #1: Cloud Interconnect
#

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
  encrypted_interconnect_router = true
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
  encryption               = "IPSEC"
  ipsec_internal_addresses = [
    google_compute_address.address_vpn_ia_1.self_link,
  ]

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
 encrypted_interconnect_router = true
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
  encryption               = "IPSEC"
  ipsec_internal_addresses = [
    google_compute_address.address_vpn_ia_2.self_link,
  ]

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


#
# Stage #2: HA VPN
#

# Begin VPN Layer
# Create HA VPN Gateways and associate with Cloud Interconnect VLAN attachments

resource "google_compute_ha_vpn_gateway" "vpngw_1" {
  name    = "vpngw-1"
  region  = "us-west2"
  network = google_compute_network.vpc_internal_custom.id
  vpn_interfaces {
    id                      = 0
    interconnect_attachment = google_compute_interconnect_attachment.sg_attach_1.self_link
  }
  vpn_interfaces {
    id                      = 1
    interconnect_attachment = google_compute_interconnect_attachment.sg_attach_2.self_link
  }
}

resource "google_compute_ha_vpn_gateway" "vpngw_2" {
  name    = "vpngw-2"
  region  = "us-west2"
  network = google_compute_network.vpc_internal_custom.id
  vpn_interfaces {
    id                      = 0
    interconnect_attachment = google_compute_interconnect_attachment.sg_attach_1.self_link
  }
  vpn_interfaces {
    id                      = 1
    interconnect_attachment = google_compute_interconnect_attachment.sg_attach_2.self_link
  }
}

# Create external peer VPN gateway resources

resource "google_compute_external_vpn_gateway" "external_vpngw_1" {
  name            = "external-vpngw-1"
  redundancy_type = "TWO_IPS_REDUNDANCY"
  interface {
    id         = 0
    ip_address = local.ext_vpn_gw_1_ip_1
  }
  interface {
    id         = 1
    ip_address = local.ext_vpn_gw_1_ip_2
  }
}

resource "google_compute_external_vpn_gateway" "external_vpngw_2" {
  name            = "external-vpngw-2"
  redundancy_type = "TWO_IPS_REDUNDANCY"
  interface {
    id         = 0
    ip_address = local.ext_vpn_gw_2_ip_1
  }
  interface {
    id         = 1
    ip_address = local.ext_vpn_gw_2_ip_2
  }
}

# Create HA VPN Cloud Router

resource "google_compute_router" "vpn_router" {
  name    = "vpn-router"
  region  = "us-west2"
  network = google_compute_network.vpc_internal_custom.self_link
  bgp {
    asn = local.vpn_router_asn
  }
}

# Create HA VPN tunnels

resource "google_compute_vpn_tunnel" "tunnel_1" {
  name                            = "tunnel-1"
  region                          = "us-west2"
  vpn_gateway                     = google_compute_ha_vpn_gateway.vpngw_1.id
  peer_external_gateway           = google_compute_external_vpn_gateway.external_vpngw_1.id
  shared_secret                   = local.shared_secret
  router                          = google_compute_router.vpn_router.id
  vpn_gateway_interface           = 0
  peer_external_gateway_interface = 0
}

resource "google_compute_vpn_tunnel" "tunnel_2" {
  name                            = "tunnel-2"
  region                          = "us-west2"
  vpn_gateway                     = google_compute_ha_vpn_gateway.vpngw_1.id
  peer_external_gateway           = google_compute_external_vpn_gateway.external_vpngw_1.id
  shared_secret                   = local.shared_secret
  router                          = google_compute_router.vpn_router.id
  vpn_gateway_interface           = 1
  peer_external_gateway_interface = 1
}

resource "google_compute_vpn_tunnel" "tunnel_3" {
  name                            = "tunnel-3"
  region                          = "us-west2"
  vpn_gateway                     = google_compute_ha_vpn_gateway.vpngw_2.id
  peer_external_gateway           = google_compute_external_vpn_gateway.external_vpngw_2.id
  shared_secret                   = local.shared_secret
  router                          = google_compute_router.vpn_router.id
  vpn_gateway_interface           = 0
  peer_external_gateway_interface = 0
}

resource "google_compute_vpn_tunnel" "tunnel_4" {
  name                            = "tunnel-4"
  region                          = "us-west2"
  vpn_gateway                     = google_compute_ha_vpn_gateway.vpngw_2.id
  peer_external_gateway           = google_compute_external_vpn_gateway.external_vpngw_2.id
  shared_secret                   = local.shared_secret
  router                          = google_compute_router.vpn_router.id
  vpn_gateway_interface           = 1
  peer_external_gateway_interface = 1
}

# Create VPN tunnel interfaces for Cloud Router

resource "google_compute_router_interface" "vpn_1_if_0" {
  name       = "vpn-1-if-0"
  region     = "us-west2"
  router     = google_compute_router.vpn_router.name
  ip_range   = local.vpn_bgp_1
  vpn_tunnel = google_compute_vpn_tunnel.tunnel_1.self_link
}

resource "google_compute_router_interface" "vpn_1_if_1" {
  name       = "vpn-1-if-1"
  region     = "us-west2"
  router     = google_compute_router.vpn_router.name
  ip_range   = local.vpn_bgp_2
  vpn_tunnel = google_compute_vpn_tunnel.tunnel_2.self_link
}

resource "google_compute_router_interface" "vpn_2_if_0" {
  name       = "vpn-2-if-0"
  region     = "us-west2"
  router     = google_compute_router.vpn_router.name
  ip_range   = local.vpn_bgp_3
  vpn_tunnel = google_compute_vpn_tunnel.tunnel_3.self_link
}

resource "google_compute_router_interface" "vpn_2_if_1" {
  name       = "vpn-2-if-1"
  region     = "us-west2"
  router     = google_compute_router.vpn_router.name
  ip_range   = local.vpn_bgp_4
  vpn_tunnel = google_compute_vpn_tunnel.tunnel_4.self_link
}

# Create BGP Peers for Cloud Router

resource "google_compute_router_peer" "vpn_peer_1" {
  name            = "vpn-peer-1"
  region          = "us-west2"
  router          = google_compute_router.vpn_router.name
  peer_ip_address = local.vpn_bgp_peer_1
  interface       = google_compute_router_interface.vpn_1_if_0.name
  peer_asn        = local.vpn_peer_asn
}

resource "google_compute_router_peer" "vpn_peer_2" {
  name            = "vpn-peer-2"
  region          = "us-west2"
  router          = google_compute_router.vpn_router.name
  peer_ip_address = local.vpn_bgp_peer_2
  interface       = google_compute_router_interface.vpn_1_if_1.name
  peer_asn        = local.vpn_peer_asn
}

resource "google_compute_router_peer" "vpn_peer_3" {
  name            = "vpn-peer-3"
  region          = "us-west2"
  router          = google_compute_router.vpn_router.name
  peer_ip_address = local.vpn_bgp_peer_3
  interface       = google_compute_router_interface.vpn_2_if_0.name
  peer_asn        = local.vpn_peer_asn
}

resource "google_compute_router_peer" "vpn_peer_4" {
  name            = "vpn-peer-4"
  region          = "us-west2"
  router          = google_compute_router.vpn_router.name
  peer_ip_address = local.vpn_bgp_peer_4
  interface       = google_compute_router_interface.vpn_2_if_1.name
  peer_asn        = local.vpn_peer_asn
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

