# Demo is assuming that:
# - firewall endpoint is already configured (provisioned)
# CAUTION! Firewall endpoint is zone based hence it needs to be provisioned in the same
# zone as resources

locals {
  zone-b = "${var.region}-b"
  zone-c = "${var.region}-c"
  subnets = [
    {
      name          = "sg-subnet-a",
      ip_cidr_range = "10.1.10.0/24",
      region        = var.region
    },
    {
      name          = "sg-subnet-b",
      ip_cidr_range = "10.1.11.0/24",
      region        = var.region
    }
  ]
}


resource "random_id" "project_id" {
  byte_length = 4
}

resource "google_project" "project" {
  org_id              = var.parent.parent_type == "organizations" ? var.parent.parent_id : null
  folder_id           = var.parent.parent_type == "folders" ? var.parent.parent_id : null
  project_id          = "${var.project_name}-${random_id.project_id.hex}"
  name                = "${var.project_name}-${random_id.project_id.hex}"
  billing_account     = var.billing_account
  auto_create_network = false
}

resource "google_project_service" "project_services" {
  for_each = toset([
    "compute.googleapis.com",
    "iap.googleapis.com",
    "networksecurity.googleapis.com"
  ])
  project = google_project.project.project_id
  service = each.value
}

resource "google_compute_network" "network" {
  project                 = google_project.project.project_id
  name                    = "sg-custom-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  for_each      = { for index, subnet in local.subnets : subnet.name => subnet }
  project       = google_project.project.project_id
  network       = google_compute_network.network.name
  region        = each.value.region
  name          = each.value.name
  ip_cidr_range = each.value.ip_cidr_range
}

resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  project = google_project.project.project_id
  network = google_compute_network.network.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = [for index, subnet in local.subnets : subnet.ip_cidr_range]

  disabled = true
}


resource "google_compute_firewall" "allow_iap" {
  name    = "allow-iap"
  project = google_project.project.project_id
  network = google_compute_network.network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
}

resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  project = google_project.project.project_id
  region  = var.region
  network = google_compute_network.network.name
  bgp {
    asn = "65001"
  }
}

resource "google_compute_router_nat" "nat" {
  project                            = google_project.project.project_id
  region                             = var.region
  name                               = "nat"
  router                             = google_compute_router.nat_router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}



resource "google_tags_tag_key" "key" {
    parent       = "organizations/${var.parent.parent_id}"
    short_name   = "security_level"
    purpose      = "GCE_FIREWALL"
    description  = "Network security level"
    purpose_data = {
      network = "${google_project.project.name}/${google_compute_network.network.name}"
  }
}

resource "google_tags_tag_value" "value" {
    parent      = "tagKeys/${google_tags_tag_key.key.name}"
    short_name  = "high"
    description = "Needs to be protected by IPS"    
}

resource "google_tags_location_tag_binding" "binding" {
    parent    = "//compute.googleapis.com/projects/${google_project.project.number}/zones/${local.zone-b}/instances/${google_compute_instance.vm_destination.instance_id}"
    tag_value = "tagValues/${google_tags_tag_value.value.name}"
    location  = local.zone-b
}

resource "google_compute_network_firewall_policy" "sg_ips_protection" {
  project     = google_project.project.project_id
  name        = "sg-ips-protection"
  description = "SG IPS scrubbing"
}  
resource "google_compute_instance" "vm_source" {
  name         = "vm-source"
  project      = google_project.project.project_id
  machine_type = "e2-medium"
  zone         = local.zone-b

  tags = ["test"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      labels = {
        my_label = "value"
      }
    }
  }

  network_interface {
    network    = google_compute_network.network.name
    subnetwork = google_compute_subnetwork.subnetwork["sg-subnet-a"].self_link
   
  #  access_config {
  #     // Ephemeral public IP
  #   }
  }

  scheduling {
    preemptible       = true
    automatic_restart = false
  }

   
  
  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }

  metadata = {
    enable-oslogin = true
  }

  metadata_startup_script = <<-EOT
          #!/bin/bash
          set -e
          echo "*****    Installing Nginx    *****"
          apt-get update
          apt-get install -y nginx
          systemctl enable nginx
          systemctl restart nginx
              
          echo "*****   Installation Complteted!!   *****"
              
          echo "Welcome to Google Compute VM Instance deployed using Terraform!!!" > /var/www/html/index.html
              
          echo "*****   Startup script completes!!    *****"
      EOT

}


resource "google_compute_instance" "vm_destination" {
  name         = "vm-destination"
  project      = google_project.project.project_id
  machine_type = "e2-medium"
  zone         = local.zone-b

  tags = ["foo", "bar"]

  boot_disk {
    initialize_params {
 #     image = "debian-cloud/debian-11"
      image  = "cos-cloud/cos-stable"
      labels = {
        my_label = "value"
      }
    }
  }

  network_interface {
    network    = google_compute_network.network.name
    subnetwork = google_compute_subnetwork.subnetwork["sg-subnet-a"].self_link
   
  #  access_config {
  #     // Ephemeral public IP
  #   }
  }

  scheduling {
    preemptible       = true
    automatic_restart = false
  }

   
  
  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }

  metadata = {
    enable-oslogin = true
  }

  metadata_startup_script = <<-EOT
          #!/bin/bash
          set -e
          echo "*****    Installing Nginx    *****"
          apt-get update
          apt-get install -y nginx
          systemctl enable nginx
          systemctl restart nginx
              
          echo "*****   Installation Complteted!!   *****"
              
          echo "Welcome to Google Compute VM Instance deployed using Terraform!!!" > /var/www/html/index.html
              
          echo "*****   Startup script completes!!    *****"
      EOT

}




