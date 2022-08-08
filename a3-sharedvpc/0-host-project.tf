module "project_host" {
  source          = "./modules/project"
  billing_account = var.billing_account
  name            = "${var.project_name_host}-${random_id.project_id.hex}"
  prefix          = "sg"
  parent          = var.parent
  services = [
    "compute.googleapis.com",
    "iap.googleapis.com"
  ]
  iam = {}
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [
    module.project_host
  ]

  create_duration = "30s"
}

module "vpc_internal_custom" {
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
      region             = "europe-central2"
      secondary_ip_range = {}

    },
    {
      ip_cidr_range      = "10.2.16.0/24"
      name               = "subnet-2"
      region             = "europe-central2"
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

module "firewall-int" {
  source = "./modules/net-vpc-firewall-yaml"

  project_id = module.project_host.project_id
  network    = module.vpc_internal_custom.name
  config_directories = [
    "./firewall-rules",
  ]
}

module "cloud-nat" {
  source         = "./modules/net-cloudnat"
  project_id     = module.project_host.project_id
  region         = "europe-central2"
  name           = "cloud-nat"
  router_network = module.vpc_internal_custom.name
  router_name    = "rtr-cloud-nat"
}

# module "spot_vm_example" {
#   source     = "./modules/compute-vm"
#   project_id = module.project.project_id
#   zone     = "europe-central2-a"
#   name       = "test-spot-vm"
#   options = {
#     allow_stopping_for_update = true
#     deletion_protection       = false
#     spot                      = true
#   }
#   network_interfaces = [{
#     network    = module.vpc_internal_custom.self_link
#     subnetwork = module.vpc_internal_custom.subnets["europe-central2/subnet-b"].self_link
#     nat        = false
#     addresses  = null
#   }]
#   service_account_create = true
#   metadata = {
#     enable-oslogin = true
#   }
# }
# tftest modules=1 resources=2
