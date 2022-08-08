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
  default = "hub-host"

}

# ------ onprem -----
variable "project_name_onprem" {
  default = "onprem"

}


# ------ Service 1 -----
variable "project_name_service_1" {
  default = "service-1"

}

# ------ Service 2 -----
variable "project_name_service_2" {
  default = "service-2"

}

variable "fortigate_int_ip" {
  default = "10.10.1.10"
}

variable "fortigate_ext_ip" {
  default = "10.100.1.10"
}