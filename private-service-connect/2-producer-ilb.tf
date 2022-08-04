
resource "google_compute_health_check" "tcp_health_check" {
  name               = "tcp-health-check"
  project            = google_project.producer.project_id
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
    health_check      = google_compute_health_check.tcp_health_check.id
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
    health_check      = google_compute_health_check.tcp_health_check.id
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


# Network load balancer, loadbalanding TCP traffic
# Source IP address is preserved (no proxy)
resource "google_compute_region_backend_service" "app_backend" {
  project               = google_project.producer.project_id
  load_balancing_scheme = "INTERNAL"

  backend {
    group          = google_compute_instance_group_manager.grp_instance_group_1.instance_group
    balancing_mode = "CONNECTION"
  }
  backend {
    group          = google_compute_instance_group_manager.grp_instance_group_2.instance_group
    balancing_mode = "CONNECTION"
  }
  name        = "app-backend"
  protocol    = "TCP"
  timeout_sec = 10

  health_checks = [google_compute_health_check.tcp_health_check.id]
}

#Forwarding rule
resource "google_compute_forwarding_rule" "app_forwarding_rule" {
  provider              = google-beta
  region                = var.region
  project               = google_project.producer.project_id
  name                  = "l4-ilb-forwarding-rule"
  backend_service       = google_compute_region_backend_service.app_backend.id
  ports                 = ["80"]
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL"
  allow_global_access   = true
  network               = google_compute_network.producer_vpc_network.id
  subnetwork            = google_compute_subnetwork.producer_sb_subnet_a.id
}