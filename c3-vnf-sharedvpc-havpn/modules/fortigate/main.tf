# ### GCP terraform
# terraform {
#   required_version = ">=0.12.0"
#   required_providers {
#     google      = ">=2.11.0"
#     google-beta = ">=2.13"
#   }
# }
# provider "google" {
#   project      = var.project
#   region       = "us-central1"
#   zone         = "us-central1-c"
#   access_token = var.token
# }
# provider "google-beta" {
#   project      = var.project
#   region       = var.region
#   zone         = var.zone
#   access_token = var.token
# }

# Randomize string to avoid duplication
resource "random_string" "random_name_post" {
  length           = 3
  special          = true
  override_special = ""
  min_lower        = 3
}

# Create log disk
resource "google_compute_disk" "logdisk" {
  project = var.project
  name = "log-disk-${random_string.random_name_post.result}"
  size = 30
  type = "pd-standard"
  zone = var.zone
}
# Create FGTVM compute instance
resource "google_compute_instance" "default" {
  project        = var.project
  name           = "fgtnat-${random_string.random_name_post.result}"
  machine_type   = var.machine
  zone           = var.zone
  can_ip_forward = "true"

  tags = ["allow-fgt", "allow-internal"]

  boot_disk {
    initialize_params {
      image = var.image
    }
  }
  attached_disk {
    source = google_compute_disk.logdisk.name
  }
  network_interface {
    subnetwork = var.public_subnet_name
    access_config {
    }
  }
  network_interface {
    subnetwork = var.private_subnet_name
  }
  metadata = {
    user-data = "${file(var.user_data)}"
    #user-data = fileexists("${path.module}/${var.user_data}") ? "${file(var.user_data)}" : null
    #license   = "${file(var.license_file)}" #this is where to put the license file if using BYOL image
    #license = fileexists("${path.module}/${var.license_file}") ? "${file(var.license_file)}" : null
  }
  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }
  scheduling {
    preemptible       = true
    automatic_restart = false
  }
}


