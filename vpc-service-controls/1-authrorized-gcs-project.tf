module "project-authorized-gcs" {
  source          = "./modules/project"
  billing_account = var.billing_account
  name            = "authorized-gcs-${random_id.project_id.hex}"
  prefix          = "sg"
  parent          = var.parent
  services = [
    "storage.googleapis.com"
  ]
  iam = {}
}

module "bucket-a" {
  source        = "./modules/gcs"
  project_id    = module.project-authorized-gcs.project_id
  prefix        = "sg"
  name          = "auth-bucket-${random_id.project_id.hex}"
  force_destroy = true
#   iam = {
#     "roles/storage.admin" = ["group:storage@example.com"]
#   }
}