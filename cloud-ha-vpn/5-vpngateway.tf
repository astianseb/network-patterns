# separate local variable for GW as it's entity is needed in a VPN local variable

locals {
    gateway = {
        project_a = {
           vpn_region       = var.vpn.project_a.vpn_region
           vpn_gateway_name = "vpn-gw-${var.projects.project_a.vpc_name}"
        }
        project_b = {
           vpn_region       = var.vpn.project_b.vpn_region
           vpn_gateway_name = "vpn-gw-${var.projects.project_b.vpc_name}"
        }
    }
}


resource "google_compute_ha_vpn_gateway" "vpn_gw" {
    for_each = local.gateway

    name    = each.value.vpn_gateway_name
    region  = each.value.vpn_region
    project = google_project.project["${each.key}"].project_id
    network = google_compute_network.network["${each.key}"].id
}



locals  {
    vpn = {
       project_a = {
           vpn_region       = var.vpn.project_a.vpn_region
           vpn_network_id   = google_compute_network.network["project_a"].id
           vpn_gateway_name = "vpn-gw-${var.projects.project_a.vpc_name}"
           vpn_router_name  = "rtr-vpn-${var.projects.project_a.vpc_name}"
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
            vpn_region       = var.vpn.project_b.vpn_region
            vpn_network_id   = google_compute_network.network["project_b"].id
            vpn_gateway_name = "vpn-gw-${var.projects.project_b.vpc_name}"
            vpn_router_name  = "rtr-vpn-${var.projects.project_b.vpc_name}"
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
                          network               = google_compute_network.network["${project}"].id

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
    network = google_compute_network.network["${each.key}"].id
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
