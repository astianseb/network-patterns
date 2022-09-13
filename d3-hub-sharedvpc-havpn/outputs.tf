# output "project_id" {
#   value = module.project.project_id
# }

# output "vm_ip" {
#     value = module.spot_vm_example.internal_ip
  
# }
output "onprem_vm_ip" {
    value = module.onprem_spot_vm_example.internal_ip
}

output "host_vm_ip" {
    value = module.host_spot_vm_example.internal_ip
  
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

output "how_to_test" {
  value = <<EOT
  1. log into "onprem VM"
  2. issue curl command to "host VM IP": curl http://${module.host_spot_vm_example.internal_ip}
  3. you may run curl in a loop: "while true; do curl http://${module.host_spot_vm_example.internal_ip}; sleep 10; done
EOT  
}

