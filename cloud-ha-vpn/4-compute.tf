resource "google_compute_instance" "cloud_instance" {
  name         = "cloud-instance"
  machine_type = "e2-medium"
  zone         = local.region-a-zone-a
  project      = google_project.project["project_a"].project_id

  tags = ["notag"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network    = google_compute_network.network["project_a"].name
    subnetwork = google_compute_subnetwork.subnet["vpc-cloud-subnet1"].self_link
  }

  scheduling {
    preemptible       = true
    automatic_restart = false
  }

  
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }


  metadata = {
    enable-oslogin = true
  }
}


resource "google_compute_instance" "onprem_instance" {
  name         = "onprem-instance"
  machine_type = "e2-medium"
  zone         = local.region-b-zone-a
  project      = google_project.project["project_b"].project_id

  tags = ["notag"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network    = google_compute_network.network["project_b"].name
    subnetwork = google_compute_subnetwork.subnet["vpc-onprem-subnet1"].self_link
  }

  scheduling {
    preemptible       = true
    automatic_restart = false
  }


  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin = true
  }
}