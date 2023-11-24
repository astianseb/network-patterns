
# For the time being (Nov, 2023) Firewall Policy Rules in terraform do not support tags
# hence the need to use gcloud

export ORGANIZATION_ID=1098571864372
export ZONE=europe-west1-b
export LOCATION=europe-west1data
export PROJECT_ID=sg-firewall-plus-81eaca58
export IP_RANGES=10.1.10.0/24

gcloud beta network-security firewall-endpoints list \
   --organization $ORGANIZATION_ID \
   --zone $ZONE \
   --project $PROJECT_ID

FIREWALL_ENDPOINT_NAME=$(gcloud beta network-security firewall-endpoints list \
   --organization $ORGANIZATION_ID \
   --zone $ZONE \
   --project $PROJECT_ID --format="value(name.basename())")

NETWORK_NAME=$(gcloud compute networks list \
   --project $PROJECT_ID \
   --format="value(name.basename())")

gcloud beta network-security firewall-endpoint-associations create sg-ips-$NETWORK_NAME-$ZONE \
   --organization $ORGANIZATION_ID \
   --endpoint $FIREWALL_ENDPOINT_NAME \
   --network $NETWORK_NAME \
   --zone $ZONE \
   --project $PROJECT_ID 

# Wait 10 minutes+
#

gcloud beta network-security firewall-endpoint-associations list \
   --project $PROJECT_ID 

gcloud beta network-security security-profiles threat-prevention \
   create sg-ips-security-profile \
   --organization $ORGANIZATION_ID \
   --location global \
   --project $PROJECT_ID \
   --description "SG Default IPS profile"

gcloud beta network-security security-profile-groups create sg-ips-security-group \
  --organization $ORGANIZATION_ID \
  --location global \
  --threat-prevention-profile organizations/$ORGANIZATION_ID/locations/global/securityProfiles/sg-ips-security-profile

gcloud beta compute network-firewall-policies rules create 2000 \
    --description "IPS protection" \
    --action apply_security_profile_group \
    --firewall-policy sg-network-policy \
    --direction INGRESS \
    --target-secure-tags $ORGANIZATION_ID/security_level/high \
    --src-ip-ranges $IP_RANGES \
    --security-profile-group //networksecurity.googleapis.com/organizations/$ORGANIZATION_ID/locations/global/securityProfileGroups/sg-ips-security-group \
    --layer4-configs all \
    --global-firewall-policy \
    --enable-logging

#Rollback
gcloud beta compute network-firewall-policies rules delete 2000 \
     --firewall-policy sg-network-policy \
     --global-firewall-policy
gcloud beta network-security security-profile-groups delete sg-ips-security-group \
  --organization $ORGANIZATION_ID 

gcloud beta network-security security-profiles threat-prevention delete sg-ips-security-profile \
  --organization $ORGANIZATION_ID 

gcloud beta network-security firewall-endpoint-associations delete sg-ips-zone-b-sg-custom-net --zone=$ZONE
