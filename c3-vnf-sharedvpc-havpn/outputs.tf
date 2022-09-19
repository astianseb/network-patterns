output "how_to_test" {
  value = <<EOT
  1. log into "onprem VM"
  2. issue curl command to Fortigate EXT IP: curl http://${module.fortigate.FortiGate-extIP}
  3. you may run curl in a loop: "while true; do curl http://${module.fortigate.FortiGate-extIP}; sleep 10; done
EOT  
}


output "project_id" {
  value = module.project_hub_host.project_id
}

output "host_vm_ip" {
    value = module.host_spot_vm_example.internal_ip
  
}
output "onprem_vm_ip" {
    value = module.onprem_spot_vm_example.internal_ip
}

output "login_to_onprem" {
  
  value = <<EOT
    gcloud beta compute ssh --zone "${var.region}-b" "${module.onprem_spot_vm_example.instance.name}" --tunnel-through-iap --project "${module.onprem_spot_vm_example.instance.project}" 
EOT
}

output "login_to_host" {
  
  value = <<EOT
    gcloud beta compute ssh --zone "${var.region}-b" "${module.host_spot_vm_example.instance.name}" --tunnel-through-iap --project "${module.host_spot_vm_example.instance.project}" 
EOT

}


output "FortiGate-NATIP" {
  value = module.fortigate.FortiGate-NATIP
  
}

output "FortiGate-InstanceName" {
  value = module.fortigate.FortiGate-InstanceName
  
}

output "FortiGate-Username" {
  value = module.fortigate.FortiGate-Username
}

output "FortiGate-Password" {
  value = module.fortigate.FortiGate-Password
  
}

output "FortiGate-intIP" {
  value = module.fortigate.FortiGAte-intIP
  
}

output "FortiGate-extIP" {
  value = module.fortigate.FortiGate-extIP
}