########### PROJECT ###############

resource "google_project" "producer" {
  name                = "${var.producer_project_name}-${random_id.id.hex}"
  project_id          = "${var.producer_project_name}-${random_id.id.hex}"
  folder_id           = try(var.folder_id, false)
  billing_account     = var.billing_account
  auto_create_network = false
}

# data "google_project" "producer" {
#     project_id = var.producer_project_id
# }


resource "google_project_service" "producer_service" {
  for_each = toset([
    "compute.googleapis.com",
    "servicedirectory.googleapis.com",
    "dns.googleapis.com"
  ])

  service            = each.key
  project            = google_project.producer.project_id
  disable_on_destroy = false
}

####### VPC NETWORK

resource "google_compute_network" "producer_vpc_network" {
  name                    = "my-internal-app"
  auto_create_subnetworks = false
  mtu                     = 1460
  project                 = google_project.producer.project_id
}


####### VPC SUBNETS

resource "google_compute_subnetwork" "producer_sb_subnet_a" {
  name          = "subnet-a"
  project       = google_project.producer.project_id
  ip_cidr_range = "10.10.20.0/24"
  network       = google_compute_network.producer_vpc_network.id
}

resource "google_compute_subnetwork" "producer_sb_subnet_b" {
  name          = "subnet-b"
  project       = google_project.producer.project_id
  ip_cidr_range = "10.10.40.0/24"
  network       = google_compute_network.producer_vpc_network.id
}

resource "google_compute_subnetwork" "proxy" {
  name          = "l7-ilb-proxy-subnet"
  project       = google_project.producer.project_id
  region        = var.region
  ip_cidr_range = "10.10.200.0/24"
  network       = google_compute_network.producer_vpc_network.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"


}

####### FIREWALL

resource "google_compute_firewall" "producer_fw-allow-internal" {
  name      = "sg-allow-internal"
  project   = google_project.producer.project_id
  network   = google_compute_network.producer_vpc_network.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [
    google_compute_subnetwork.producer_sb_subnet_a.ip_cidr_range,
    google_compute_subnetwork.producer_sb_subnet_b.ip_cidr_range]
}

resource "google_compute_firewall" "producer_fw_allow_ssh" {
  name      = "sg-allow-ssh"
  project   = google_project.producer.project_id
  network   = google_compute_network.producer_vpc_network.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "producer_fw_app_allow_http" {
  name      = "sg-app-allow-http"
  project   = google_project.producer.project_id
  network   = google_compute_network.producer_vpc_network.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["80", "8080"]
  }
  target_tags   = ["lb-backend"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "producer_fw_app_allow_health_check" {
  name      = "sg-app-allow-health-check"
  project   = google_project.producer.project_id
  network   = google_compute_network.producer_vpc_network.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }
  target_tags   = ["lb-backend"]
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

#### NAT

resource "google_compute_router" "producer_router" {
  name    = "nat-router"
  project = google_project.producer.project_id
  network = google_compute_network.producer_vpc_network.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "producer_nat" {
  name                               = "my-router-nat"
  project                            = google_project.producer.project_id
  router                             = google_compute_router.producer_router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

###################### HTTP Regional LB #####################

resource "google_compute_region_health_check" "tcp_health_check" {
  name               = "tcp-health-check"
  project            = google_project.producer.project_id
  region             = var.region 
  timeout_sec        = 1
  check_interval_sec = 1


  tcp_health_check {
    port = "80"
  }
}


// ------------- Instance Group A
resource "google_compute_instance_template" "tmpl_instance_group_1" {
  name                 = "instance-group-1"
  project              = google_project.producer.project_id
  description          = "SG instance group of preemptible hosts"
  instance_description = "description assigned to instances"
  machine_type         = "e2-medium"
  can_ip_forward       = false
  tags                 = ["lb-backend"]

  scheduling {
    preemptible       = true
    automatic_restart = false

  }
  
  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }

  // Create a new boot disk from an image
  disk {
    source_image = "debian-cloud/debian-10"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network            = google_compute_network.producer_vpc_network.name
    subnetwork         = google_compute_subnetwork.producer_sb_subnet_a.name
    subnetwork_project = google_project.producer.project_id
  }

  metadata = {
    startup-script-url = "gs://cloud-training/gcpnet/ilb/startup.sh"
  }
}

#MIG-a
resource "google_compute_instance_group_manager" "grp_instance_group_1" {
  name               = "instance-group-1"
  project            = google_project.producer.project_id
  base_instance_name = "mig-a"
  zone               = local.zone-a
  version {
    instance_template = google_compute_instance_template.tmpl_instance_group_1.id
  }

  auto_healing_policies {
    health_check      = google_compute_region_health_check.tcp_health_check.id
    initial_delay_sec = 300
  }
}

resource "google_compute_autoscaler" "obj_my_autoscaler_a" {
  name    = "my-autoscaler-a"
  project = google_project.producer.project_id
  zone    = local.zone-a
  target  = google_compute_instance_group_manager.grp_instance_group_1.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 1
    cooldown_period = 45

    cpu_utilization {
      target = 0.8
    }
  }
}


//----------------Instance Group B

resource "google_compute_instance_template" "tmpl_instance_group_2" {
  name                 = "instance-group-2"
  project              = google_project.producer.project_id
  description          = "SG instance group of preemptible hosts"
  instance_description = "description assigned to instances"
  machine_type         = "e2-medium"
  can_ip_forward       = false
  tags                 = ["lb-backend"]

  scheduling {
    preemptible       = true
    automatic_restart = false

  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }

  disk {
    source_image = "debian-cloud/debian-10"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network            = google_compute_network.producer_vpc_network.name
    subnetwork         = google_compute_subnetwork.producer_sb_subnet_b.name
    subnetwork_project = google_project.producer.project_id
  }

  metadata = {
    startup-script-url = "gs://cloud-training/gcpnet/ilb/startup.sh"
  }
}

resource "google_compute_instance_group_manager" "grp_instance_group_2" {
  name               = "instance-group-2"
  project            = google_project.producer.project_id
  base_instance_name = "mig-b"
  zone               = local.zone-b
  version {
    instance_template = google_compute_instance_template.tmpl_instance_group_2.id
  }

  auto_healing_policies {
    health_check      = google_compute_region_health_check.tcp_health_check.id
    initial_delay_sec = 300
  }
}

resource "google_compute_autoscaler" "obj_my_autoscaler_b" {
  name    = "my-autoscaler-b"
  project = google_project.producer.project_id
  zone    = local.zone-b
  target  = google_compute_instance_group_manager.grp_instance_group_2.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 1
    cooldown_period = 45

    cpu_utilization {
      target = 0.8
    }
  }
}



# forwarding rule
resource "google_compute_forwarding_rule" "app_forwarding_rule" {
  name                  = "l7-ilb-forwarding-rule"
  provider              = google-beta
  region                = var.region
  project               = google_project.producer.project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.default.id
 # ip_address            = google_compute_address.default.id
  network               = google_compute_network.producer_vpc_network.id
  subnetwork            = google_compute_subnetwork.producer_sb_subnet_a.id
  allow_global_access   = true

}

# http proxy
resource "google_compute_region_target_http_proxy" "default" {
  name     = "l7-ilb-target-http-proxy"
  provider = google-beta
  region   = var.region
  project  = google_project.producer.project_id
  url_map  = google_compute_region_url_map.default.id
}

# url map
resource "google_compute_region_url_map" "default" {
  name            = "l7-ilb-url-map"
  provider        = google-beta
  region          = var.region
  project         = google_project.producer.project_id
  default_service = google_compute_region_backend_service.app_backend.id
}


# HTTP regional load balancer (envoy based)
resource "google_compute_region_backend_service" "app_backend" {
  name                     = "l7-ilb-backend-service"
  provider                 = google-beta
  region                   = var.region
  project                  = google_project.producer.project_id
  protocol                 = "HTTP"
  port_name                = "my-port"
  load_balancing_scheme    = "INTERNAL_MANAGED"
  timeout_sec              = 10
  health_checks            = [google_compute_region_health_check.tcp_health_check.id]
  backend {
    group           = google_compute_instance_group_manager.grp_instance_group_1.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
  backend {
    group           = google_compute_instance_group_manager.grp_instance_group_2.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}


############ PUBLISH ########

resource "google_compute_subnetwork" "sb_subnet_psc" {
  name          = "subnet-psc"
  project       = google_project.producer.project_id
  ip_cidr_range = "10.10.100.0/24"
  network       = google_compute_network.producer_vpc_network.id
  purpose       =  "PRIVATE_SERVICE_CONNECT"

}

resource "google_compute_service_attachment" "psc_service_attachment" {
  name        = "my-psc-ilb"
  region      = var.region
  project     = google_project.producer.project_id
  description = "A service attachment configured with Terraform"

 # domain_names             = ["gcp.tfacc.hashicorptest.com."]
  enable_proxy_protocol    = false
  connection_preference    = "ACCEPT_AUTOMATIC"
  nat_subnets              = [google_compute_subnetwork.sb_subnet_psc.id]
  target_service           = google_compute_forwarding_rule.app_forwarding_rule.id
}


############### SIEGE HOST #####################

# Instance to host siege (testing tool for LB)
# usage: siege -i --concurrent=50 http://<lb-ip>
#

resource "google_compute_instance" "producer_siege_host" {
  name         = "producer-siege-host"
  machine_type = "e2-medium"
  zone         = local.zone-a
  project      = google_project.producer.project_id

  tags = ["siege"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network    = google_compute_network.producer_vpc_network.name
    subnetwork = google_compute_subnetwork.producer_sb_subnet_a.self_link
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


  metadata_startup_script = <<-EOF1
      #! /bin/bash
      set -euo pipefail

      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y siege
     EOF1

}