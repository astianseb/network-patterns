locals {
  zone-a = "${var.region}-a"
  zone-b = "${var.region}-b"
}

provider "google" {
  region = var.region
}

resource "random_id" "id" {
  byte_length = 4
  prefix      = "sg"
}
