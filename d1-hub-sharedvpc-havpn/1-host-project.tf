module "project_host" {
  source          = "./modules/project"
  billing_account = var.billing_account
  name            = "${var.project_name_host}-${random_id.project_id.hex}"
  prefix          = "sg"
  parent          = "organizations/1098571864372"
  services = [
    "compute.googleapis.com",
    "iap.googleapis.com"
  ]
  iam = {}
}

module "shared_vpc_internal_custom" {
  source     = "./modules/net-vpc"
  project_id = module.project_host.project_id

  depends_on = [
      time_sleep.wait_30_seconds
  ]
  name = "shared-vpc-internal"
  subnets = [
    {
      ip_cidr_range      = "10.2.1.0/24"
      name               = "subnet-1"
      region             = var.region
      secondary_ip_range = {}

    },
    {
      ip_cidr_range      = "10.2.16.0/24"
      name               = "subnet-2"
      region             = var.region
      secondary_ip_range = {}
    }
  ]
  shared_vpc_host = true
  shared_vpc_service_projects = [
 #     local.service_project_1.project_id,
 #     local.service_project_2.project_id
      
#    module.project_service_1.project_id,
#    module.project_service_2.project_id
  ]

}

module "firewall_int" {
  source = "./modules/net-vpc-firewall-yaml"

  project_id = module.project_host.project_id
  network    = module.shared_vpc_internal_custom.name
  config_directories = [
    "./firewall-rules",
  ]
}

module "shared_vpc_cloud_nat" {
  source         = "./modules/net-cloudnat"
  project_id     = module.project_host.project_id
  region         = var.region
  name           = "cloud-nat"
  router_network = module.shared_vpc_internal_custom.name
  router_name    = "rtr-cloud-nat"
}

module "host_spot_vm_example" {
  source     = "./modules/compute-vm"
  project_id = module.project_host.project_id
  zone     = "${var.region}-b"
  name       = "host-test-spot-vm"
  options = {
    allow_stopping_for_update = true
    deletion_protection       = false
    spot                      = true
  }
  network_interfaces = [{
    network    = module.shared_vpc_internal_custom.self_link
    subnetwork = module.shared_vpc_internal_custom.subnets["${var.region}/subnet-1"].self_link
    nat        = false
    addresses  = null
  }]
  service_account_create = true
  metadata = {
    enable-oslogin = true
    startup-script-url = "gs://cloud-training/gcpnet/ilb/startup.sh"
  }
}
