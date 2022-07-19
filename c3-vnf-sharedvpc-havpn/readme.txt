host_vm_ip = "10.2.1.2"
login_to_host = <<EOT
    gcloud beta compute ssh --zone "europe-west1-b" "host-test-spot-vm" --tunnel-through-iap --project "sg-host-3e0d4554" 

EOT
login_to_onprem = <<EOT
    gcloud beta compute ssh --zone "europe-west1-b" "onprem-test-spot-vm" --tunnel-through-iap --project "sg-onprem-3e0d4554" 

EOT
onprem_vm_ip = "10.200.1.2"

