locals {
  zone-b = "${var.region}-b"
  zone-c = "${var.region}-c"
  networks = [
    "net-a",
    "net-b"
  ]
  subnets = [
    {
      name          = "subnet-1",
      ip_cidr_range = "10.1.10.0/24",
      region        = var.region
    },
    {
      name          = "subnet-2",
      ip_cidr_range = "10.1.11.0/24",
      region        = var.region
    }
  ]
  subnets_scheme = flatten([ for k,v in local.networks :
                               [for k1,v1 in local.subnets :
                                 { network     = v,
                                   subnet_name = v1.name,
                                   cidr        = v1.ip_cidr_range,
                                   region      = v1.region}]])

  instances = [
    {
      name    = "vm-a",
      network = "net-a"
      subnet  = "subnet-1"
     },
     {
      name    = "vm-b",
      network = "net-b"
      subnet  = "subnet-2"
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
    "networkconnectivity.googleapis.com" 
  ])
  project = google_project.project.project_id
  service = each.value
}

resource "google_compute_network" "network" {
  project                 = google_project.project.project_id
  
  for_each                = toset(local.networks) 
  name                    = each.value
  auto_create_subnetworks = false
}



resource "google_compute_subnetwork" "subnetwork" {
  project       = google_project.project.project_id

  for_each      = tomap({for k in local.subnets_scheme : "${k.network}-${k.subnet_name}" => k})
  network       = google_compute_network.network["${each.value.network}"].name
  name          = "${each.value.network}-${each.value.subnet_name}"
  region        = each.value.region
  ip_cidr_range = each.value.cidr
}

resource "google_compute_firewall" "allow_internal" {
  project   = google_project.project.project_id

  for_each  = toset(local.networks)
  name      = "allow-internal-${each.value}"
  network   = google_compute_network.network["${each.value}"].name

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
}


resource "google_compute_firewall" "allow_iap" {
  project  = google_project.project.project_id

  for_each = toset(local.networks)
  name     = "allow-iap-${each.value}"
  network  = google_compute_network.network["${each.value}"].name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
}

resource "google_compute_router" "nat_router" {
  project = google_project.project.project_id

  for_each = toset(local.networks)
  name     = "nat-router-${each.value}"
  region   = var.region
  network  = google_compute_network.network["${each.value}"].name
  bgp {
    asn = "65001"
  }
}

resource "google_compute_router_nat" "nat_a" {
  project                            = google_project.project.project_id

  for_each                           = toset(local.networks)
  name                               = "nat-${each.value}"
  region                             = var.region
  router                             = google_compute_router.nat_router["${each.value}"].name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_instance" "vm" {
  project      = google_project.project.project_id

  for_each     = tomap({for k in local.instances : "${k.name}-${k.network}" => k})
  name         = "${each.value.name}-${each.value.network}-${each.value.subnet}"
  machine_type = "e2-medium"
  zone         = local.zone-b

  tags = ["foo", "bar"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      labels = {
        my_label = "value"
      }
    }
  }

  network_interface {
    network    = google_compute_network.network["${each.value.network}"].name
    subnetwork = google_compute_subnetwork.subnetwork["${each.value.network}-${each.value.subnet}"].self_link
  }

  scheduling {
    preemptible       = true
    automatic_restart = false
  }

  #   access_config {
  #     // Ephemeral public IP
  #   }
  # }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }

  metadata = {
    enable-oslogin = true
    startup-script-url = "gs://cloud-training/gcpnet/ilb/startup.sh"

  }

}



########### NCC ###############


resource "google_network_connectivity_hub" "sg_hub" {
  project      = google_project.project.project_id

  name         = "sg-hub"
  description  = "SG test hub"  
}


#### Currenly VPC as a spoke does not have terraform resource yet