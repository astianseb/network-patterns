module "project-authorized-compute" {
  source          = "./modules/project"
  billing_account = var.billing_account
  name            = "authorized-compute-${random_id.project_id.hex}"
  prefix          = "sg"
  parent          = var.parent
  services = [
    "compute.googleapis.com",
    "iap.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ]
  iam = {}
}

module "vpc_internal_custom" {
  source     = "./modules/net-vpc"
  project_id = module.project-authorized-compute.project_id

  depends_on = [
    time_sleep.wait_30_seconds
  ]
  name = "vpc-internal-custom"
  subnets = [
    {
      ip_cidr_range      = "10.2.0.0/24"
      name               = "subnet-a"
      region             = var.region
      secondary_ip_range = {}

    },
    {
      ip_cidr_range      = "10.2.16.0/24"
      name               = "subnet-b"
      region             = var.region
      secondary_ip_range = {}
    },
    {
      ip_cidr_range      = "10.2.32.0/24"
      name               = "subnet-c"
      region             = var.region
      secondary_ip_range = {}
    }
  ]
}

module "firewall-int" {
  source = "./modules/net-vpc-firewall-yaml"

  project_id = module.project-authorized-compute.project_id
  network    = module.vpc_internal_custom.name
  config_directories = [
    "./firewall-rules",
  ]
}

module "cloud-nat" {
  source         = "./modules/net-cloudnat"
  project_id     = module.project-authorized-compute.project_id
  region         = var.region
  name           = "cloud-nat"
  router_network = module.vpc_internal_custom.name
  router_name    = "rtr-cloud-nat"
}

module "vm_a" {
  source        = "./modules/compute-vm"
  project_id    = module.project-authorized-compute.project_id
  zone          = "${var.region}-b"
#  instance_type = "n2-highcpu-32"
  name          = "vm-a"
   options = {
    allow_stopping_for_update = true
    deletion_protection       = false
    spot                      = true
    termination_action        = "STOP"    
  }
  network_interfaces = [{
    network    = module.vpc_internal_custom.self_link
    subnetwork = module.vpc_internal_custom.subnets["${var.region}/subnet-b"].self_link
    nat        = false
    addresses  = null
  }]
  service_account_create = true
  metadata = {
    enable-oslogin = true
  }
}

# For the sake of the exercise, we set OWNER role to the SA on the organization level
# because we'll use that SA to query GCS buckets in a different projects 
resource "google_organization_iam_member" "sa_owner" {
  org_id  = var.org_id
  role    = "roles/owner"
  member  = "serviceAccount:${module.vm_a.service_account.email}"
}

resource "google_service_account_iam_member" "sa_user" {
  service_account_id = module.vm_a.service_account.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:me@sebastiang.eu"
}

resource "google_service_account_iam_member" "sa_token_creator" {
  service_account_id = module.vm_a.service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:me@sebastiang.eu"
}
