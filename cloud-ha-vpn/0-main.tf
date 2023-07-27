locals {
  region-a-zone-a = "${var.region_a}-b"
  region-a-zone-b = "${var.region_a}-b"
  region-b-zone-a = "${var.region_b}-b"
  region-b-zone-b = "${var.region_b}-c"
}

provider "google" {
}
