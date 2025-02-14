variable "parent" {
  type = object({
    parent_type = string
    parent_id   = string
  })
  default = {
    parent_id   = null
    parent_type = null
  }
}

variable "region_a" {}

variable "region_b" {}

#variable "billing_account" {}

#variable "producer_project_name" {}

variable "sg_project_id" {}

variable "sg_prefix" {}



