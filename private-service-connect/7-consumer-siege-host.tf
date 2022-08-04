# Instance to host siege (testing tool for LB)
# usage: siege -i --concurrent=50 http://<lb-ip>
#

resource "google_compute_instance" "consumer_siege_host" {
  name         = "consumer-siege-host"
  machine_type = "e2-medium"
  zone         = local.zone-a
  project      = google_project.consumer.project_id

  tags = ["siege"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network    = google_compute_network.consumer_vpc_network.name
    subnetwork = google_compute_subnetwork.consumer_sb_subnet_a.self_link
  }

  scheduling {
    preemptible       = true
    automatic_restart = false
  }

  metadata = {
    enable-oslogin = true
  }


  metadata_startup_script = <<-EOF1
      #! /bin/bash
      set -euo pipefail

      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y siege
     EOF1

}