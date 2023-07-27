variable "region_a" {}
variable "region_b" {}


variable "billing_account" {}

variable "projects" {
  type = map(any)
  default = {
    project_a = {
      name     = "prj-cloud"
      vpc_name = "vpc-cloud"
    }
    project_b = {
      name     = "prj-onprem"
      vpc_name = "vpc-onprem"
    }
  }

}

variable "vpn"  {
    default = {
        ip_ranges = {
            tunnel_1 = "169.254.0.0/30"
            tunnel_2 = "169.254.0.4/30"
        }
        secret = "kluczyk."
        project_a = {
            vpn_region = "europe-central2"
            router_asn = "65001"
        }
        project_b = {
            vpn_region = "europe-central2"
            router_asn = "65002"
        }
    }
}
