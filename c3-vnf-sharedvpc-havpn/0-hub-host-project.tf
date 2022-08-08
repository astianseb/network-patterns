module "project_hub_host" {
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



module "vpc_external" {
  source     = "./modules/net-vpc"
  project_id = module.project_hub_host.project_id

  depends_on = [
      time_sleep.wait_30_seconds
  ]
  name = "vpc-external"
  subnets = [
    {
      ip_cidr_range      = "10.100.1.0/24"
      name               = "ext-subnet-1"
      region             = var.region
      secondary_ip_range = {}

    },
    {
      ip_cidr_range      = "10.100.16.0/24"
      name               = "ext-subnet-2"
      region             = var.region
      secondary_ip_range = {}
    }
  ]
  
}

module "vpc_internal" {
  source     = "./modules/net-vpc"
  project_id = module.project_hub_host.project_id

  depends_on = [
      time_sleep.wait_30_seconds
  ]
  name = "vpc-internal"
  subnets = [
    {
      ip_cidr_range      = "10.10.1.0/24"
      name               = "int-subnet-1"
      region             = var.region
      secondary_ip_range = {}

    },
    {
      ip_cidr_range      = "10.10.16.0/24"
      name               = "int-subnet-2"
      region             = var.region
      secondary_ip_range = {}
    }
  ]
  shared_vpc_host = true
  shared_vpc_service_projects = [
    # module.project_service_1.project_id,
    # module.project_service_2.project_id
  ]

  
}


module "hub_firewall_ext" {
  source             = "./modules/net-vpc-firewall-yaml"
  project_id         = module.project_hub_host.project_id
  network            = module.vpc_external.name
  config_directories = [
    "./firewall-rules-ext",
  ]
}

module "hub_firewall_int" {
  source             = "./modules/net-vpc-firewall-yaml"
  project_id         = module.project_hub_host.project_id
  network            = module.vpc_internal.name
  config_directories = [
    "./firewall-rules-int",
  ]
}

module "cloud_nat" {
  source         = "./modules/net-cloudnat"
  project_id     = module.project_hub_host.project_id
  region         = var.region
  name           = "cloud-nat"
  router_network = module.vpc_internal.name
  router_name    = "rtr-cloud-nat"
}

#----------- Fortigate

# resource "null_resource" "set_fgt_config" {
#   provisioner "set" {
#     command = "./fortigate-config/set-variables.sh"
  
#   provisioner "set_default" {
#     when    = destroy
#     command = "./fortigate-config/set-default.sh"
#   }

#   }  
# }



module "fortigate" {
  project = module.project_hub_host.project_id
  source = "./modules/fortigate"
  zone   = "${var.region}-b"
  user_data = "./fortigate-config/config.txt"
  public_subnet_name = module.vpc_external.subnets["${var.region}/ext-subnet-1"].self_link
  private_subnet_name = module.vpc_internal.subnets["${var.region}/int-subnet-1"].self_link
  int_ip = var.fortigate_int_ip
  ext_ip = var.fortigate_ext_ip

}


#-----------   HA-VPN  

module "vpn_ha_cloud" {
  source           = "./modules/net-vpn-ha"
  project_id       = module.project_hub_host.project_id
  region           = var.region
  network          = module.vpc_external.self_link
  name             = "to-onprem"
  peer_gcp_gateway = module.vpn_ha_onprem.self_link
  router_asn       = 64614
  router_advertise_config = {
    groups = []
    ip_ranges = {
      "10.100.1.0/24" = "ext-subnet-1",
      "10.100.16.0/24" = "ext-subnet-2"

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


module "host_spot_vm_example" {
  source     = "./modules/compute-vm"
  project_id = module.project_hub_host.project_id
  zone     = "${var.region}-b"
  name       = "cloud-test-spot-vm"
  options = {
    allow_stopping_for_update = true
    deletion_protection       = false
    spot                      = true
  }
  network_interfaces = [{
    network    = module.vpc_internal.self_link
    subnetwork = module.vpc_internal.subnets["${var.region}/int-subnet-1"].self_link
    nat        = false
    addresses  = {
      internal = "10.10.1.100"
      external = null
    }
  }]
  service_account_create = true
  metadata = {
    enable-oslogin = true
    startup-script-url = "gs://cloud-training/gcpnet/ilb/startup.sh"
  }
}

