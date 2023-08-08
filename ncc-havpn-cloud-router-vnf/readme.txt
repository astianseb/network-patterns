https://cloud.google.com/network-connectivity/docs/network-connectivity-center/how-to/creating-router-appliances#gcloud_6

---
router bgp 64600
 bgp log-neighbor-changes
 neighbor 10.1.1.101 remote-as 64601
 neighbor 10.1.1.102 remote-as 64601
 neighbor 10.1.10.101 remote-as 64610
 neighbor 10.1.10.102 remote-as 64610
 
!         

----




gcloud compute routers create cloud-rtr-outside \
      --region=europe-west1 \
      --network=outside \
      --asn=64601 \
      --project=prj-cloud-8be05002
      
gcloud compute routers add-interface cloud-rtr-outside \
    --interface-name=interface-outside-1 \
    --ip-address=10.1.1.101 \
    --subnetwork=vpc-cloud-subnet1 \
    --region=europe-west1 \
    --project=prj-cloud-8be05002

gcloud compute routers add-interface cloud-rtr-outside \
    --interface-name=interface-outside-2 \
    --ip-address=10.1.1.102 \
    --subnetwork=vpc-cloud-subnet1 \
    --redundant-interface=interface-outside-1 \
    --region=europe-west1 \
    --project=prj-cloud-8be05002


# NCC with router appliance spokes needs to be configured before provisioning BGP peers

gcloud compute routers add-bgp-peer cloud-rtr-outside \
      --peer-name=cisco-rtr-outside-peer-1 \
      --interface=interface-outside-1 \
      --peer-ip-address=10.1.1.3 \
      --peer-asn=64600 \
      --instance=vm-rtr-1 \
      --instance-zone=europe-west1-b \
      --region=europe-west1 \
      --project=prj-cloud-8be05002
      
gcloud compute routers add-bgp-peer cloud-rtr-outside \
      --peer-name=cisco-rtr-outside-peer-2 \
      --interface=interface-outside-1 \
      --peer-ip-address=10.1.1.3 \
      --peer-asn=64600 \
      --instance=vm-rtr-1 \
      --instance-zone=europe-west1-b \
      --region=europe-west1 \
      --project=prj-cloud-8be05002


---------------


gcloud compute routers create cloud-rtr-inside \
      --region=europe-west1 \
      --network=inside \
      --asn=64610 \
      --project=prj-cloud-8be05002

      
gcloud compute routers add-interface cloud-rtr-inside \
    --interface-name=interface-inside-1 \
    --ip-address=10.1.10.101 \
    --subnetwork=inside-subnet1 \
    --region=europe-west1 \
    --project=prj-cloud-8be05002

gcloud compute routers add-interface cloud-rtr-inside \
    --interface-name=interface-inside-2 \
    --ip-address=10.1.10.102 \
    --subnetwork=inside-subnet1 \
    --redundant-interface=interface-inside-1 \
    --region=europe-west1 \
    --project=prj-cloud-8be05002


gcloud compute routers add-bgp-peer cloud-rtr-inside \
      --peer-name=cisco-rtr-inside-peer-1 \
      --interface=interface-inside-1 \
      --peer-ip-address=10.1.10.4 \
      --peer-asn=64600 \
      --instance=vm=rtr-1 \
      --instance-zone=europe-west1-b \
      --region=europe-west1 \
      --project=prj-cloud-8be05002
      
gcloud compute routers add-bgp-peer cloud-rtr-inside \
      --peer-name=cisco-rtr-inside-peer-2 \
      --interface=interface-inside-2 \
      --peer-ip-address=10.1.10.4 \
      --peer-asn=64600 \
      --instance=vm-rtr-1 \
      --instance-zone=europe-west1-b \
      --region=europe-west1 \
      --project=prj-cloud-8be05002
