module "project_service_1" {
  source          = "./modules/project"
  billing_account = var.billing_account
  name            = "${var.project_name_service_1}-${random_id.project_id.hex}"
  prefix          = "sg"
  parent          = var.parent
  services = [
    "compute.googleapis.com",
    "iap.googleapis.com"
  ]
  iam = {}
}

