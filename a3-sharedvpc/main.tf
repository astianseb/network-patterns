locals {
  service_project_1 = {
    project_id = module.project_service_1.project_id
  }
  service_project_2 = {
    project_id = module.project_service_2.project_id
  }
}

resource "random_id" "project_id" {
  byte_length = 4
}