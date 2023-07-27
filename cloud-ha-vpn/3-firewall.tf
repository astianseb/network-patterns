
######### Cloud VPC  ###############

locals {
    firewall_rules_cloud = {
        "vpc-cloud-allow-internal" = {
            protocols = {
                tcp           = []
                udp           = []
                icmp          = []}
            source_ranges = [for cidr in local.projects.project_a.subnets : cidr.subnet_cidr ]
                }
         "vpc-cloud-allow-ftp" = {
            protocols = {
                tcp           = ["21"]}
            source_ranges = ["0.0.0.0/0" ]
                }
        "vpc-cloud-allow-ssh-rdp" = {
            protocols = {
                tcp = ["22", "3389"]
                icmp = []}
            source_ranges = ["0.0.0.0/0"]
        }
        "vpc-cloud-allow-icmp" = {
            protocols = {
                icmp = []}
            source_ranges = ["0.0.0.0/0" ]
                }
    }
}

######### Onprem VPC  ###############


locals {
    firewall_rules_onprem = {
        "vpc-onprem-allow-internal" = {
            protocols = {
                tcp = []
                udp = []
                icmp = []}
            source_ranges = [for cidr in local.projects.project_b.subnets : cidr.subnet_cidr ]
                }
        "vpc-onprem-allow-ssh" = {
            protocols = {
                tcp = ["22"]
                icmp = []}
            source_ranges = ["0.0.0.0/0"]
        }
        "vpc-onprem-allow-icmp" = {
            protocols = {
                icmp = []}
            source_ranges = ["0.0.0.0/0" ]
                }
    }
}

locals {
    rules_cloud = {for k,v in local.firewall_rules_cloud : 
                    "${k}" => toset([for k1,v1 in v.protocols :
                        {"protocol" = k1,"ports" = v1}])
                } 
}

locals {
    rules_onprem = {for k,v in local.firewall_rules_onprem :
                    "${k}" => toset([for k1,v1 in v.protocols :
                        {"protocol" = k1, "ports" = v1} ]) } 
}

resource "google_compute_firewall" "rule_cloud" {
    for_each = local.firewall_rules_cloud
    name      = each.key
    project   = google_project.project["project_a"].project_id
    network   = google_compute_network.network["project_a"].name
    direction = "INGRESS"
    source_ranges = each.value.source_ranges
    dynamic "allow" {
        for_each = local.rules_cloud["${each.key}"]
        content {
            protocol = allow.value.protocol
            ports = allow.value.ports
        }
    }
}

resource "google_compute_firewall" "rule_onprem" {
    for_each = local.firewall_rules_onprem
    name      = each.key
    project   = google_project.project["project_b"].project_id
    network   = google_compute_network.network["project_b"].name
    direction = "INGRESS"
    source_ranges = each.value.source_ranges
    dynamic "allow" {
        for_each = local.rules_onprem["${each.key}"]
        content {
            protocol = allow.value.protocol
            ports = allow.value.ports
        }
    }
}

