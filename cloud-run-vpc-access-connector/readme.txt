1. run terraform
2. create NCC hub
3. issue commands

gcloud beta compute networks subnets create nat-subnet \
    --network=net-a \
    --region=europe-west1 \
    --range=192.168.1.0/24 \
    --purpose=PRIVATE_NAT

gcloud compute routers create internal-nat-rtr \
  --network=net-a --region=europe-west1

gcloud beta compute routers nats create sg-private-nat \
  --router=internal-nat-rtr --type=PRIVATE --region=europe-west1 \
  --nat-custom-subnet-ip-ranges=net-a-subnet-1:ALL \
  --enable-logging

gcloud beta compute routers nats create sg-private-nat \
  --router=internal-nat-rtr --type=PRIVATE --region=europe-west1 \
  --nat-all-subnet-ip-ranges \
  --enable-logging


gcloud beta compute routers nats delete sg-private-nat \
  --router=internal-nat-rtr --region=europe-west1 

gcloud beta compute routers nats rules create 1 \
  --router=internal-nat-rtr --region=europe-west1 \
  --nat=sg-private-nat \
  --match='nexthop.hub == "//networkconnectivity.googleapis.com/projects/sg-private-nat-2b4a4ea8/locations/global/hubs/sg-hub"' \
  --source-nat-active-ranges=nat-subnet

----
gcloud beta compute routers nats describe sg-private-nat \
  --router=internal-nat-rtr \
  --region=europe-west1

gcloud beta compute routers get-nat-mapping-info internal-nat-rtr \
  --region=europe-west1

gcloud beta compute routers get-status internal-nat-rtr \
  --region=europe-west1
