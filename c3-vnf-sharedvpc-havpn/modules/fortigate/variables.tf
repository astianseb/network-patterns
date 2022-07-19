# GCP region
variable "region" {
  type    = string
  default = "us-central1" #Default Region
}
# GCP zone
variable "zone" {
  type    = string
  default = "us-central1-c" #Default Zone
}
# GCP project name
variable "project" {
  type    = string
  default = "<gcp project>"
}

# FortiGate Image name
# 7.0.5 payg is projects/fortigcp-project-001/global/images/fortinet-fgtondemand-705-20220211-001-w-license
# 7.0.5 byol is projects/fortigcp-project-001/global/images/fortinet-fgt-705-20220211-001-w-license
variable "image" {
  type    = string
  default = "projects/fortigcp-project-001/global/images/fortinet-fgtondemand-705-20220211-001-w-license"
}

# GCP instance machine type
variable "machine" {
  type    = string
  default = "n1-standard-1"
}
# Public Subnet name
variable "public_subnet_name" {
  type    = string
}
# Private Subnet name
variable "private_subnet_name" {
  type    = string
}

# user data for bootstrap fgt configuration
variable "user_data" {
  type    = string
  default = "config.txt"
}

# user data for bootstrap fgt license file
variable "license_file" {
  type    = string
  default = "license.lic" #FGT BYOL license
}