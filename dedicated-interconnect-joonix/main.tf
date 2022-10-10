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
  project_id = var.dedicated_ic_project_id
}

module "vpc_internal_custom" {
  source     = "./modules/net-vpc"
  project_id = var.dedicated_ic_project_id

  name = "vpc-internal-custom"
  subnets = [
    {
      ip_cidr_range      = "10.2.0.0/24"
      name               = "subnet-a"
      region             = "us-west2"
      secondary_ip_range = {}

    },
    {
      ip_cidr_range      = "10.2.16.0/24"
      name               = "subnet-b"
      region             = "us-west2"
      secondary_ip_range = {}
    }
  ]
}

module "cloud-nat" {
  source         = "./modules/net-cloudnat"
  project_id     = var.dedicated_ic_project_id
  region         = "us-west2"
  name           = "cloud-nat"
  router_network = module.vpc_internal_custom.name
  router_name    = "rtr-cloud-nat"
}


module "vlan-attachment-1" {
  source      = "./modules/net-interconnect-attachment-direct"
  project_id  = var.dedicated_ic_project_id
  region      = "us-west2"
  router_name = "ic-router-1"
  router_config = {
    description = ""
    asn         = local.asn
    advertise_config = {
      groups = ["ALL_SUBNETS"]
      ip_ranges = {
        "199.36.153.8/30" = "custom"
      }
      mode = "CUSTOM"
    }
  }
  router_network = module.vpc_internal_custom.name
  name           = "vlan-${local.vlan_id}-1"
  interconnect   = "https://www.googleapis.com/compute/v1/projects/cso-lab-management/global/interconnects/cso-lab-interconnect-1"

  config = {
    description   = ""
    vlan_id       = local.vlan_id
    bandwidth     = "BPS_10G"
    admin_enabled = true
    mtu           = 1440
  }
  peer = {
      ip_address = local.bgp_ip_address_1
      asn        = 65418
  }
  bgp = {
      session_range             = local.bgp_session_range_1
      advertised_route_priority = 0
      candidate_ip_ranges       = [local.bgp_candidate_ip_ranges_1]
  }
}

module "vlan-attachment-2" {
  source      = "./modules/net-interconnect-attachment-direct"
  project_id  = var.dedicated_ic_project_id
  region      = "us-west2"
  router_name = "ic-router-2"
  router_config = {
    description = ""
    asn         = local.asn
    advertise_config = {
      groups = ["ALL_SUBNETS"]
      ip_ranges = {
        "199.36.153.8/30" = "custom"
      }
      mode = "CUSTOM"
    }

  }
  router_network = module.vpc_internal_custom.name
  name           = "vlan-${local.vlan_id}-2"

  interconnect   = "https://www.googleapis.com/compute/v1/projects/cso-lab-management/global/interconnects/cso-lab-interconnect-2"

  config = {
    description   = ""
    vlan_id       = local.vlan_id
    bandwidth     = "BPS_10G"
    admin_enabled = true
    mtu           = 1440
  }
  peer = {
    ip_address = local.bgp_ip_address_2
    asn        = 65418
  }
  bgp = {
    session_range             = local.bgp_session_range_2
    advertised_route_priority = 0
    candidate_ip_ranges       = [local.bgp_candidate_ip_ranges_2]
  }
}





module "vm_a" {
  source        = "./modules/compute-vm"
  project_id    = var.dedicated_ic_project_id
  zone          = "us-west2-a"
  name          = "vm-a"
   options = {
    allow_stopping_for_update = true
    deletion_protection       = false
    spot                      = true
    termination_action        = "STOP"    
  }
  network_interfaces = [{
    network    = module.vpc_internal_custom.self_link
    subnetwork = module.vpc_internal_custom.subnets["us-west2/subnet-a"].self_link
    nat        = false
    addresses  = null
  }]
  service_account_create = true
  metadata = {
    enable-oslogin = true
  }
  tags = [
      "bastion",
      "internet-egress"
  ]
}

resource "google_compute_firewall" "vm_a" {
  name    = "bastion-allow-ssh"
  network = module.vpc_internal_custom.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_tags = ["bastion"]
}

