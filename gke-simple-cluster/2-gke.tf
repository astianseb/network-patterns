#Subnetwok and FW rule ne

resource "google_compute_subnetwork" "proxy_only" {
  name          = "proxy-only-subnet"
  ip_cidr_range = "192.168.100.0/24"
  project   = google_project.gke.project_id
  region        = var.region
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
  network       = google_compute_network.gke_vpc_network.id
}

# Firewall rule to allow traffic from Envoy to forwarding 
# rule created by Ingress object
resource "google_compute_firewall" "allow_proxy_connection" {
  name      = "allow-proxy-connection"
  project   = google_project.gke.project_id
  network   = google_compute_network.gke_vpc_network.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
#    ports    = ["80"]

  }

  source_ranges = [
    "192.168.100.0/24"]
}



module "cluster_1" {
  source                    = "./modules/gke-cluster"
  project_id                = google_project.gke.project_id
  name                      = "cluster-1"
  location                  = local.zone-a
  network                   = google_compute_network.gke_vpc_network.self_link
  subnetwork                = google_compute_subnetwork.gke_sb_subnet_a.self_link
  secondary_range_pods      = "pods"
  secondary_range_services  = "services"
  default_max_pods_per_node = 32
  # master_authorized_ranges = {
  #   internal-vms = "10.0.0.0/8",
  #   sg-pixelbook = "193.34.178.14/32",
  #   gcp_shell    = "34.90.199.253/32"
  # }
  private_cluster_config = {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "192.168.0.0/28"
    master_global_access    = false
  }
  labels = {
    environment = "dev"
  }
}

resource "time_sleep" "wait_30_seconds" {
  create_duration = "30s"
}

module "cluster_1_nodepool_1" {
  source                      = "./modules/gke-nodepool"
  depends_on                  = [time_sleep.wait_30_seconds]
  project_id                  = google_project.gke.project_id
  cluster_name                = "cluster-1"
  location                    = local.zone-a
  name                        = "nodepool-1"
  node_preemptible            = true
  initial_node_count          = 2
  node_machine_type           = "e2-medium"
}
