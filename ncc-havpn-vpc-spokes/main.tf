
provider "google" {
}

locals {
  region-a-zone-a = "${var.region_a}-b"
  region-a-zone-b = "${var.region_a}-b"
  region-b-zone-a = "${var.region_b}-b"
  region-b-zone-b = "${var.region_b}-c"
}

locals {
  projects = {
    project_a = {
      name     = "${var.projects.project_a.name}"
      vpc_list = [
        {
            vpc_name = "outside"
            subnets  = [
                { 
                    subnet_name   = "outside-subnet1"
                    subnet_cidr   = "10.1.1.0/24"
                    subnet_region = var.region_a
                },
                {
                    subnet_name   = "outside-subnet2"
                    subnet_cidr   = "10.1.2.0/24"
                    subnet_region = var.region_a
                }]
            nat_router_name   = "nat-rtr"
            nat_router_region = var.region_a
            nat_router_asn    = "64514"
            
        },
       
      ]
    }
    project_b = {
      name     = "${var.projects.project_b.name}"
      vpc_list = [
        {
            vpc_name = "vpc"
            subnets  = [
                { 
                    subnet_name   = "subnet1"
                    subnet_cidr   = "10.2.1.0/24"
                    subnet_region = var.region_a
                },
                {
                    subnet_name   = "subnet2"
                    subnet_cidr   = "10.2.2.0/24"
                    subnet_region = var.region_a
                }]
            nat_router_name   = "nat-rtr"
            nat_router_region = var.region_a
            nat_router_asn    = "64515"
            
        }
      ]
    }
    project_c = {
      name     = "${var.projects.project_c.name}"
      vpc_list = [
        {
            vpc_name = "vpc"
            subnets  = [
                { 
                    subnet_name   = "subnet1"
                    subnet_cidr   = "10.100.1.0/24"
                    subnet_region = var.region_a
                }]
            nat_router_name   = "nat-rtr"
            nat_router_region = var.region_a
            nat_router_asn    = "64516"
            
        }
      ]
    }
    project_d = {
      name     = "${var.projects.project_d.name}"
      vpc_list = [
        {
            vpc_name = "vpc"
            subnets  = [
                { 
                    subnet_name   = "subnet1"
                    subnet_cidr   = "10.101.1.0/24"
                    subnet_region = var.region_a
                }]
            nat_router_name   = "nat-rtr"
            nat_router_region = var.region_a
            nat_router_asn    = "64517"
            
        }
      ]
    }
  }
}

resource "random_id" "id" {
  byte_length = 4
}


resource "google_project" "project" {
  for_each = var.projects

  name                = "${each.value.name}-${random_id.id.hex}"
  project_id          = "${each.value.name}-${random_id.id.hex}"
  billing_account     = var.billing_account
  auto_create_network = false
}

resource "google_project_service" "service" {
  for_each = local.projects

  service            = "compute.googleapis.com"
  project            = google_project.project[each.key].project_id
  disable_on_destroy = false
}

resource "google_project_service" "service_iap" {
  for_each = local.projects

  service            = "iap.googleapis.com"
  project            = google_project.project[each.key].project_id
  disable_on_destroy = false
}


resource "google_project_service" "ncc" {
  for_each = local.projects

  service            = "networkconnectivity.googleapis.com"
  project            = google_project.project[each.key].project_id
  disable_on_destroy = false
}



locals {
  networks = flatten([for project_index,project_data in local.projects: [
                        for vpc_details in project_data.vpc_list: {
                              project_index = project_index
                              vpc_name      = vpc_details.vpc_name}]])
  
  subnets = flatten([for project_index,project_data in local.projects: [
                      for vpc_details in project_data.vpc_list: [
                        for subnet in vpc_details.subnets: {
                                project_index     = project_index,
                                project_name      = project_data.name,
                                vpc_name          = vpc_details.vpc_name
                                subnet_name       = subnet.subnet_name
                                subnet_cidr       = subnet.subnet_cidr
                                subnet_region     = subnet.subnet_region
                                nat_router_name   = vpc_details.nat_router_name
                                nat_router_region = vpc_details.nat_router_region
                                nat_router_asn    = vpc_details.nat_router_asn }]]])
  
  routers = flatten([for project_index,project_data in local.projects: [
                            for vpc_details in project_data.vpc_list: [
                              for subnet in vpc_details.subnets: {
                                     project_index     = project_index,
                                     vpc_name          = vpc_details.vpc_name
                                     nat_router_name   = vpc_details.nat_router_name
                                     nat_router_region = vpc_details.nat_router_region
                                     nat_router_asn    = vpc_details.nat_router_asn }]]])
}

resource "google_compute_network" "network" {
  for_each = tomap({ for k,v in local.networks : "${v.project_index}_${v.vpc_name}" => v })

  name                    = each.value.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  mtu                     = 1460
  project                 = google_project.project["${each.value.project_index}"].project_id
}


resource "google_compute_subnetwork" "subnet" {
  for_each = tomap({ for k,v in local.subnets : "${v.project_index}_${v.vpc_name}_${v.subnet_name}" => v })
  
  name          = each.value.subnet_name
  region        = each.value.subnet_region
  project       = google_project.project["${each.value.project_index}"].project_id
  ip_cidr_range = each.value.subnet_cidr
  network       = google_compute_network.network["${each.value.project_index}_${each.value.vpc_name}"].id
}



resource "google_compute_router" "nat_router" {
  for_each = { for k,v in distinct(local.routers) : "${v.project_index}_${v.vpc_name}_${k}" => v} 
  
  name    = "${each.value.nat_router_name}-${each.value.vpc_name}"
  region  = each.value.nat_router_region
  project = google_project.project["${each.value.project_index}"].project_id
  network = google_compute_network.network["${each.value.project_index}_${each.value.vpc_name}"].id 

  
  bgp {
    asn = each.value.nat_router_asn
  }
  }


resource "google_compute_router_nat" "nat_policy" {
  for_each = tomap({ for k,v in distinct(local.routers) : "${v.project_index}_${v.vpc_name}_${k}" => v })
  
  name                               = "${each.value.nat_router_name}-nat"
  region                             = each.value.nat_router_region
  project                            = google_project.project["${each.value.project_index}"].project_id
  router                             = google_compute_router.nat_router["${each.key}"].name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "rule" {
    for_each = tomap({ for k,v in local.networks : "${v.project_index}_${v.vpc_name}" => v })

    name          = "sg-allow-all-${each.value.vpc_name}"
    project       = google_project.project["${each.value.project_index}"].project_id
    network       = google_compute_network.network["${each.value.project_index}_${each.value.vpc_name}"].id 
    direction     = "INGRESS"
    source_ranges = ["0.0.0.0/0"]

    allow {
        protocol = "icmp"
    }

    allow {
        protocol = "tcp"
        ports    = ["22", "80", "443"]
     }

}




#------------Compute
resource "google_compute_instance" "cloud_instance" {
  for_each     = tomap({ for k,v in local.subnets : "${v.project_index}_${v.vpc_name}_${v.subnet_name}" => v })

  name         = "vm-${each.value.vpc_name}-${each.value.subnet_name}"
  machine_type = "e2-small"
  zone         = local.region-a-zone-a
  project      = google_project.project["${each.value.project_index}"].project_id

  tags = ["notag"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network    = google_compute_network.network["${each.value.project_index}_${each.value.vpc_name}"].name
    subnetwork = google_compute_subnetwork.subnet["${each.value.project_index}_${each.value.vpc_name}_${each.value.subnet_name}"].self_link
  }

  scheduling {
    preemptible       = true
    automatic_restart = false
  }

  
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }


  metadata = {
    enable-oslogin = true
  }
}


#-----------------VPN Gateway 

# separate local variable for GW as it's entity is needed in a VPN local variable
# semi automatic. VPN is set between VPC "outside" in project_a and VPC "vpc" in project_b
locals {
    gateway = {
        project_a = {
           vpn_region       = var.vpn.project_a.vpn_region
           vpn_gateway_name = "vpn-gw-cloud"
           vpc_name         = "outside"
        }
        project_b = {
           vpn_region       = var.vpn.project_b.vpn_region
           vpn_gateway_name = "vpn-gw-onprem"
           vpc_name         = "vpc"
        }
    }
}


resource "google_compute_ha_vpn_gateway" "vpn_gw" {
    for_each = local.gateway

    name    = each.value.vpn_gateway_name
    region  = each.value.vpn_region
    project = google_project.project["${each.key}"].project_id
    network = google_compute_network.network["${each.key}_${each.value.vpc_name}"].id
}



locals  {
    vpn = {
       project_a = {
           vpc_name         = local.gateway.project_a.vpc_name
           vpn_region       = var.vpn.project_a.vpn_region
           vpn_network_id   = google_compute_network.network["project_a_${local.gateway.project_a.vpc_name}"].id
           vpn_gateway_name = "vpn-gw-cloud"
           vpn_router_name  = "rtr-vpn-cloud"
           vpn_router_asn   = var.vpn.project_a.router_asn
           vpn_project_id   = google_project.project["project_a"].project_id
           tunnels          = [
               {
                   peer_gcp_gateway_id   = google_compute_ha_vpn_gateway.vpn_gw["project_b"].id
                   peer_gcp_gateway_name = google_compute_ha_vpn_gateway.vpn_gw["project_b"].name
                   secret                = var.vpn.secret
                   interface =  {
                          ip_range = "${cidrhost(var.vpn.ip_ranges.tunnel_1, 1)}/30"
                          bgp_peer = "${cidrhost(var.vpn.ip_ranges.tunnel_1, 2)}"
                          peer_asn = var.vpn.project_b.router_asn
                      }
               },
               {
                   peer_gcp_gateway_id   = google_compute_ha_vpn_gateway.vpn_gw["project_b"].id
                   peer_gcp_gateway_name = google_compute_ha_vpn_gateway.vpn_gw["project_b"].name
                   secret                = var.vpn.secret
                   interface = {
                          ip_range = "${cidrhost(var.vpn.ip_ranges.tunnel_2, 1)}/30"
                          bgp_peer = "${cidrhost(var.vpn.ip_ranges.tunnel_2, 2)}"
                          peer_asn = var.vpn.project_b.router_asn
                        }
               }
           ]
        }
        project_b = {
            vpc_name         = local.gateway.project_b.vpc_name
            vpn_region       = var.vpn.project_b.vpn_region
            vpn_network_id   = google_compute_network.network["project_b_${local.gateway.project_b.vpc_name}"].id
            vpn_gateway_name = "vpn-gw-onprem"
            vpn_router_name  = "rtr-vpn-onprem"
            vpn_router_asn   = var.vpn.project_b.router_asn
            vpn_project_id   = google_project.project["project_b"].project_id
            tunnels = [
               {
                   peer_gcp_gateway_id   = google_compute_ha_vpn_gateway.vpn_gw["project_a"].id
                   peer_gcp_gateway_name = google_compute_ha_vpn_gateway.vpn_gw["project_a"].name
                   secret                = var.vpn.secret
                   interface =  {
                          ip_range = "${cidrhost(var.vpn.ip_ranges.tunnel_1, 2)}/30"
                          bgp_peer = "${cidrhost(var.vpn.ip_ranges.tunnel_1, 1)}"
                          peer_asn = var.vpn.project_a.router_asn
                      }
               },
                {
                   peer_gcp_gateway_id   = google_compute_ha_vpn_gateway.vpn_gw["project_a"].id
                   peer_gcp_gateway_name = google_compute_ha_vpn_gateway.vpn_gw["project_a"].name
                   secret                = var.vpn.secret
                   interface =  {
                          ip_range = "${cidrhost(var.vpn.ip_ranges.tunnel_2, 2)}/30"
                          bgp_peer = "${cidrhost(var.vpn.ip_ranges.tunnel_2, 1)}"
                          peer_asn = var.vpn.project_a.router_asn
                        }
               }

                  ]
               
        }
    } 
}


locals {
    vpn_data = flatten([ for project, project_vars in local.vpn : 
                   [ for tunnel_index, tunnel_vars in project_vars.tunnels : 
                      {   region                = project_vars.vpn_region
                          project               = google_project.project["${project}"].project_id
                          project_name          = google_project.project["${project}"].name
                          network               = google_compute_network.network["${project}_${project_vars.vpc_name}"].id

                          vpn_gateway           = google_compute_ha_vpn_gateway.vpn_gw["${project}"].id, 
                          vpn_router_name       = google_compute_router.vpn_router["${project}"].name
                          vpn_router_id         = google_compute_router.vpn_router["${project}"].id
                          vpn_router_asn        = project_vars.vpn_router_asn
                          tunnel_name           = "${project}"
                          peer_gcp_gateway      = tunnel_vars.peer_gcp_gateway_id
                          peer_gcp_gateway_name = tunnel_vars.peer_gcp_gateway_name
                          shared_secret         = tunnel_vars.secret
                          ip_range              = tunnel_vars.interface.ip_range
                          tunnel_index          = tunnel_index
                          peer_ip_address       = tunnel_vars.interface.bgp_peer
                          peer_asn              = tunnel_vars.interface.peer_asn
                       
                      }]])
}


resource "google_compute_router" "vpn_router" {
    for_each = local.vpn

    name    = each.value.vpn_router_name
    region  = each.value.vpn_region
    project = google_project.project["${each.key}"].project_id
    network = google_compute_network.network["${each.key}_${each.value.vpc_name}"].id
    bgp {
      asn = each.value.vpn_router_asn
     }
    }


resource "google_compute_vpn_tunnel" "tunnel" {
    for_each = { for k,v in local.vpn_data : "${k}" => v }

    name                  = "tunnel-${each.key}-to-${each.value.peer_gcp_gateway_name}"
    region                = each.value.region
    project               = each.value.project
    vpn_gateway           = each.value.vpn_gateway
    peer_gcp_gateway      = each.value.peer_gcp_gateway
    shared_secret         = each.value.shared_secret
    router                = each.value.vpn_router_id
    vpn_gateway_interface = each.value.tunnel_index
}

resource "google_compute_router_interface" "interface" {
    for_each = { for k,v in local.vpn_data : "${k}" => v }

    name       = "interface-${each.key}-${each.value.vpn_router_name}"
    router     = each.value.vpn_router_name
    region     = each.value.region
    project    = each.value.project
    ip_range   = each.value.ip_range
    vpn_tunnel = google_compute_vpn_tunnel.tunnel["${each.key}"].name
}

resource "google_compute_router_peer" "peer" {
    for_each = { for k,v in local.vpn_data : "${k}" => v }

    name                      = "peer-${each.key}-${each.value.vpn_router_name}"
    router                    = each.value.vpn_router_name
    region                    = each.value.region
    project                   = each.value.project
    peer_ip_address           = each.value.peer_ip_address
    peer_asn                  = each.value.peer_asn
    advertised_route_priority = "100"
    interface                 = google_compute_router_interface.interface["${each.key}"].name
}
