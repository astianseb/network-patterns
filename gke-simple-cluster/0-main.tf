locals {
  zone-a = "${var.region}-b"
  zone-b = "${var.region}-c"
}

provider "google" {
  region = var.region
}

resource "random_id" "id" {
  byte_length = 4
  prefix      = "sg"
}
