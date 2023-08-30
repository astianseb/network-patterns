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

variable "billing_account" {
  type = string
}

variable "region" {
  type = string
}

variable "project_name" {
  type = string
}