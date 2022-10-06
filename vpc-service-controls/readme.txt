Context:
------------------------------------
Service perimeter is using default organization policy:
"gcloud organizations list"
"gcloud access-context-manager policies list --organization=<org id>"
in my case it is: 
vpc-service-controls gcloud access-context-manager policies list --organization=1098571864372
NAME          ORGANIZATION   SCOPES  TITLE           ETAG
969293738262  1098571864372          default policy  6bcd7c8d2864ba0d

Perimeter needs to be set with service-account (with relevant rights) therefore we have providers
authenticated with SA impersonation

Setup:
------------------------------------
We have 3 projects:
- sg-authorized-compute-c86eff99
- sg-authorized-gcs-c86eff99
- sg-notauthorized-gcs-c86eff99

and 2 GCS buckets:
- sg-auth-bucket-c86eff99
- sg-notauth-bucket-c86eff99


EXAMPLE 1
Basic service perimeter which allows compute (AND/OR) storage API between authorized projects
No granurality in this example. Just full compute & storage API is restricted/allowed
GCS testing:
 "gsutil ls gs://sg-auth-bucket-c86eff99"    / outcome: PASS
 "gsutil ls gs://sg-notauth-bucket-c86eff99" / outcome: BLOCKED by policy
Compute testing:
 "gcloud compute instances list --project=sg-notauthorized-gcs-c86eff99" / outomce: BLOCKED by policy
 "gcloud compute instances list --project=sg-authorized-gcs-c86eff99"    / outcome: PASS

CAVEAT: because this policy is simple (no ingress rule, it needs to be manually deleted from console before
        a second apply (after changes) otherwise it will be blocked by policy:
        "gcloud access-context-manager perimeters delete <perimeter_name>""

module "service-perimeter-a" {
  source        = "./modules/vpc-sc"
  providers = {
    google      = google.sa_authenticated,
    google-beta = google-beta.sa_authenticated
   }
  access_policy = "969293738262"
  access_levels = {}
  service_perimeters_regular = {
    perimeter_a = {
      spec = null
      status = {
        access_levels       = []
        resources           = [
            "projects/${module.project-authorized-compute.number}",
            "projects/${module.project-authorized-gcs.number}"]
        restricted_services = [
            "storage.googleapis.com",
            "compute.googleapis.com"]
        egress_policies     = []
        ingress_policies    = []
        vpc_accessible_services = {
          allowed_services   = []
          enable_restriction = false
        }
      }
      use_explicit_dry_run_spec = false
    }
  }
}



EXAMPLE 2
Similar to example #1 but perimeter will be based only a single project and
API access between authorized project will be implemented using EGRESS rules
Below policy is prohibiting compute (ALL) and allows only GCS API to authrized project
GCS testing:
 "gsutil ls gs://sg-auth-bucket-c86eff99"    / outcome: PASS
 "gsutil ls gs://sg-notauth-bucket-c86eff99" / outcome: BLOCKED by policy
Compute testing:
 "gcloud compute instances list --project=sg-notauthorized-gcs-c86eff99" / outomce: BLOCKED by policy
 "gcloud compute instances list --project=sg-authorized-gcs-c86eff99"    / outcome: BLOCKED by policy


module "service-perimeter-b" {
  source        = "./modules/vpc-sc"
  providers = {
    google      = google.sa_authenticated,
    google-beta = google-beta.sa_authenticated
   }
  access_policy = "969293738262"
  access_levels = {}
  service_perimeters_regular = {
    perimeter_b = {
      spec = null
      status = {
        access_levels       = []
        resources           = [
            "projects/${module.project-authorized-compute.number}"
        ]
        restricted_services = [
            "storage.googleapis.com",
            "compute.googleapis.com"]
        egress_policies     = [
            {
                egress_from = {
                    identity_type = null
                    identities = [
                        "serviceAccount:${module.vm_a.service_account.email}"
                    ]
                }
                egress_to = {
                    operations = [{
                        method_selectors = ["*"], service_name = "storage.googleapis.com"
                    }]
                    resources = ["projects/${module.project-authorized-gcs.number}"]
                }
            }
        ]
        ingress_policies    = []
        vpc_accessible_services = {
          allowed_services   = []
          enable_restriction = false
        }
      }
      use_explicit_dry_run_spec = false
    }
  }
}