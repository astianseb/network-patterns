provider "google" {
    impersonate_service_account = module.vm_a.service_account.email
    alias = "sa_authenticated"
}

provider "google-beta" {
    impersonate_service_account = module.vm_a.service_account.email
    alias = "sa_authenticated"
}

# EXAMPLE 1

# module "service-perimeter-a" {
#   source        = "./modules/vpc-sc"
#   providers = {
#     google      = google.sa_authenticated,
#     google-beta = google-beta.sa_authenticated
#    }
#   access_policy = "969293738262"
#   access_levels = {}
#   service_perimeters_regular = {
#     perimeter_a = {
#       spec = null
#       status = {
#         access_levels       = []
#         resources           = [
#             "projects/${module.project-authorized-compute.number}",
#             "projects/${module.project-authorized-gcs.number}"]
#         restricted_services = [
#             "storage.googleapis.com",
#             "compute.googleapis.com"]
#         egress_policies     = []
#         ingress_policies    = []
#         vpc_accessible_services = {
#           allowed_services   = []
#           enable_restriction = false
#         }
#       }
#       use_explicit_dry_run_spec = false
#     }
#   }
# }



# EXAMPLE 2

# module "service-perimeter-b" {
#   source        = "./modules/vpc-sc"
#   providers = {
#     google      = google.sa_authenticated,
#     google-beta = google-beta.sa_authenticated
#    }
#   access_policy = "969293738262"
#   access_levels = {}
#   service_perimeters_regular = {
#     perimeter_b = {
#       spec = null
#       status = {
#         access_levels       = []
#         resources           = [
#             "projects/${module.project-authorized-compute.number}"
#         ]
#         restricted_services = [
#             "storage.googleapis.com",
#             "compute.googleapis.com"]
#         egress_policies     = [
#             {
#                 egress_from = {
#                     identity_type = null
#                     identities = [
#                         "serviceAccount:${module.vm_a.service_account.email}"
#                     ]
#                 }
#                 egress_to = {
#                     operations = [{
#                         method_selectors = ["*"], service_name = "storage.googleapis.com"
#                     }]
#                     resources = ["projects/${module.project-authorized-gcs.number}"]
#                 }
#             }
#         ]
#         ingress_policies    = []
#         vpc_accessible_services = {
#           allowed_services   = []
#           enable_restriction = false
#         }
#       }
#       use_explicit_dry_run_spec = false
#     }
#   }
# }