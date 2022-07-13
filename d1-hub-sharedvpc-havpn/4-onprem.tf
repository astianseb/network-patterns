module "project_onprem" {
  source          = "./modules/project"
  billing_account = var.billing_account
  name            = "${var.project_name_onprem}-${random_id.project_id.hex}"
  prefix          = "sg"
  parent          = "organizations/1098571864372"
  services = [
    "compute.googleapis.com",
    "iap.googleapis.com"
  ]
  iam = {}
}



module "onprem_vpc_internal_custom" {
  source     = "./modules/net-vpc"
  project_id = module.project_onprem.project_id

  depends_on = [
      time_sleep.wait_30_seconds
  ]
  name = "onprem-vpc-internal"
  subnets = [
    {
      ip_cidr_range      = "10.200.1.0/24"
      name               = "subnet-1"
      region             = var.region
      secondary_ip_range = {}

    },
    {
      ip_cidr_range      = "10.200.16.0/24"
      name               = "subnet-2"
      region             = var.region
      secondary_ip_range = {}
    }
  ]
  
}


module "onprem_firewall_int" {
  source = "./modules/net-vpc-firewall-yaml"

  project_id = module.project_onprem.project_id
  network    = module.onprem_vpc_internal_custom.name
  config_directories = [
    "./firewall-rules",
  ]
}

module "onprem_cloud_nat" {
  source         = "./modules/net-cloudnat"
  project_id     = module.project_onprem.project_id
  region         = var.region
  name           = "cloud-nat"
  router_network = module.onprem_vpc_internal_custom.name
  router_name    = "rtr-cloud-nat"
}

module "vpn_ha_onprem" {
  source           = "./modules/net-vpn-ha"
  project_id       = module.project_onprem.project_id
  region           = var.region
  network          = module.onprem_vpc_internal_custom.self_link
  name             = "to-cloud"
  peer_gcp_gateway = module.vpn_ha_cloud.self_link
  router_asn       = 64613
  router_advertise_config = {
    groups = ["ALL_SUBNETS"]
    ip_ranges = {}
    mode = "CUSTOM"
  }
  tunnels = {
    remote-0 = {
      bgp_peer = {
        address = "169.254.1.2"
        asn     = 64614
      }
      bgp_peer_options                = null
      bgp_session_range               = "169.254.1.1/30"
      ike_version                     = 2
      peer_external_gateway_interface = null
      router                          = null
      shared_secret                   = "klucz"
      vpn_gateway_interface           = 0
    }
    remote-1 = {
      bgp_peer = {
        address = "169.254.2.2"
        asn     = 64614
      }
      bgp_peer_options                = null
      bgp_session_range               = "169.254.2.1/30"
      ike_version                     = 2
      peer_external_gateway_interface = null
      router                          = null
      shared_secret                   = "klucz"
      vpn_gateway_interface           = 1
    }
  }
}

module "onprem_spot_vm_example" {
  source     = "./modules/compute-vm"
  project_id = module.project_onprem.project_id
  zone     = "${var.region}-b"
  name       = "onprem-test-spot-vm"
  options = {
    allow_stopping_for_update = true
    deletion_protection       = false
    spot                      = true
  }
  network_interfaces = [{
    network    = module.onprem_vpc_internal_custom.self_link
    subnetwork = module.onprem_vpc_internal_custom.subnets["${var.region}/subnet-1"].self_link
    nat        = false
    addresses  = null
  }]
  service_account_create = true
  metadata = {
    enable-oslogin = true
    startup-script-url = "gs://cloud-training/gcpnet/ilb/startup.sh"
  }
}

