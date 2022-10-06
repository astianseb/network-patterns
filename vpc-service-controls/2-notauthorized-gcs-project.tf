module "project-notauthorized-gcs" {
  source          = "./modules/project"
  billing_account = var.billing_account
  name            = "notauthorized-gcs-${random_id.project_id.hex}"
  prefix          = "sg"
  parent          = var.parent
  services = [
    "storage.googleapis.com"
  ]
  iam = {}
}

module "bucket-na" {
  source        = "./modules/gcs"
  project_id    = module.project-notauthorized-gcs.project_id
  prefix        = "sg"
  name          = "notauth-bucket-${random_id.project_id.hex}"
  force_destroy = true

#   iam = {
#     "roles/storage.admin" = ["group:storage@example.com"]
#   }
}