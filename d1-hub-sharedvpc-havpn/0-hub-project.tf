module "project_hub" {
  source          = "./modules/project"
  billing_account = var.billing_account
  name            = "${var.project_name_hub}-${random_id.project_id.hex}"
  prefix          = "sg"
  parent          = var.parent
  services = [
    "compute.googleapis.com",
    "iap.googleapis.com"
  ]
  iam = {}
}



module "hub_vpc_internal_custom" {
  source     = "./modules/net-vpc"
  project_id = module.project_hub.project_id

  depends_on = [
      time_sleep.wait_30_seconds
  ]
  name = "hub-vpc-internal"
  subnets = [
    {
      ip_cidr_range      = "10.100.1.0/24"
      name               = "subnet-1"
      region             = var.region
      secondary_ip_range = {}

    },
    {
      ip_cidr_range      = "10.100.16.0/24"
      name               = "subnet-2"
      region             = var.region
      secondary_ip_range = {}
    }
  ]
  
}

module "peering_hub_sharedvpc" {
  source                     = "./modules/net-vpc-peering"
  prefix                     = "sg"
  local_network              = module.hub_vpc_internal_custom.network.id
  peer_network               = module.shared_vpc_internal_custom.network.id
  export_local_custom_routes = true
}


module "hub_firewall_int" {
  source             = "./modules/net-vpc-firewall-yaml"
  project_id         = module.project_hub.project_id
  network            = module.hub_vpc_internal_custom.name
  config_directories = [
    "./firewall-rules",
  ]
}

# module "hub_cloud_nat" {
#   source         = "./modules/net-cloudnat"
#   project_id     = module.project_hub.project_id
#   region         = var.region
#   name           = "cloud-nat"
#   router_network = module.hub_vpc_internal_custom.name
#   router_name    = "rtr-cloud-nat"
# }



#-----------   HA-VPN  

module "vpn_ha_cloud" {
  source           = "./modules/net-vpn-ha"
  project_id       = module.project_hub.project_id
  region           = var.region
  network          = module.hub_vpc_internal_custom.self_link
  name             = "to-onprem"
  peer_gcp_gateway = module.vpn_ha_onprem.self_link
  router_asn       = 64614
  router_advertise_config = {
    groups = ["ALL_SUBNETS"]
    ip_ranges = {
      "10.2.1.0/24" = "host-subnet-1",
      "10.2.16.0/24" = "host-subnet-2"
    }
    mode = "CUSTOM"
  }
  tunnels = {
    remote-0 = {
      bgp_peer = {
        address = "169.254.1.1"
        asn     = 64613
      }
      bgp_peer_options                = null
      bgp_session_range               = "169.254.1.2/30"
      ike_version                     = 2
      peer_external_gateway_interface = null
      router                          = null
      shared_secret                   = "klucz"
      vpn_gateway_interface           = 0
    }
    remote-1 = {
      bgp_peer = {
        address = "169.254.2.1"
        asn     = 64613
      }
      bgp_peer_options                = null
      bgp_session_range               = "169.254.2.2/30"
      ike_version                     = 2
      peer_external_gateway_interface = null
      router                          = null
      shared_secret                   = "klucz"
      vpn_gateway_interface           = 1
    }
  }
}
