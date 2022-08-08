# ----- Global -----
variable "billing_account" {
  default = "015A40-CE2160-A88AE1"

}

variable "parent" {
  default = "organizations/1098571864372"
  description = "format: organizations/<orgid> or folders/<folderid>"
  
}

variable "region" {
  default = "europe-west1"
}


# ----- Hub Project -----
variable "project_name_hub" {
  default = "hub"

}

# ------ onprem -----
variable "project_name_onprem" {
  default = "onprem"

}

# ----- Host Project -----
variable "project_name_host" {
  default = "host"

}

# ------ Service 1 -----
variable "project_name_service_1" {
  default = "service-1"

}

# ------ Service 2 -----
variable "project_name_service_2" {
  default = "service-2"

}

