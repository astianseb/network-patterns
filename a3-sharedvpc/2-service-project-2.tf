module "project_service_2" {
  source          = "./modules/project"
  billing_account = var.billing_account
  name            = "${var.project_name_service_2}-${random_id.project_id.hex}"
  prefix          = "sg"
  parent          = "organizations/1098571864372"
  services = [
    "compute.googleapis.com",
    "iap.googleapis.com"
  ]
  iam = {}
}