locals {
  subnets = flatten([for project, subnet in local.projects :
                          [for k, v in subnet.subnets :
                            { project       = project,
                              subnet_name   = v.subnet_name,
                              subnet_region = v.subnet_region,
                              subnet_cidr   = v.subnet_cidr }]])

}

resource "google_compute_network" "network" {
  for_each = local.projects

  name                    = each.value.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  mtu                     = 1460
  project                 = google_project.project["${each.key}"].project_id
}

resource "google_compute_subnetwork" "subnet" {
  for_each = { for item in local.subnets : "${item.subnet_name}" => item }

  name          = each.value.subnet_name
  region        = each.value.subnet_region
  project       = google_project.project["${each.value.project}"].project_id
  ip_cidr_range = each.value.subnet_cidr
  network       = google_compute_network.network["${each.value.project}"].id
}


resource "google_compute_router" "router" {
  for_each = local.projects

  name    = each.value.nat_router_name
  region  = each.value.nat_router_region
  project = google_project.project["${each.key}"].project_id
  network = google_compute_network.network["${each.key}"].id
  
  bgp {
    asn = each.value.nat_router_asn
  }
}

resource "google_compute_router_nat" "nat_policy" {
  for_each                           = local.projects
  name                               = "${each.value.nat_router_name}-nat"
  region                             = each.value.nat_router_region
  project                            = google_project.project["${each.key}"].project_id
  router                             = google_compute_router.router["${each.key}"].name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

