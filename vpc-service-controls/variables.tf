variable "billing_account" {
  default = "015A40-CE2160-A88AE1"
}

variable "org_id" {
  default = "1098571864372"
}

variable "parent" {
  default = "organizations/1098571864372"
  description = "format: organizations/<org ID> or folders/<folder ID>"
}

variable "region" {
  default = "europe-west2"
}