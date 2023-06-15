
# gcloud alpha compute network-attachments create consumer-na \
#   --region=europe-west2 \
#   --connection-preference=ACCEPT_AUTOMATIC \
#   --subnets=subnet-a
#   --project=sg-consumer
#
# gcloud alpha compute network-attachments list
# gcloud alpha compute network-attachments describe consumer-na --region=europe-west2

# gcloud alpha compute instances create producer-vm \
#   --no-address \
#   --zone europe-west2-a \
#   --machine-type=f1-micro \
#   --network-interface subnet=subnet-a,no-address \
#   --network-interface 'network-attachment=projects/sg-consumer/regions/europe-west2/networkAttachments/consumer-na' \
#   --project=sg-producer \
#   --shielded-secure-boot \
#   --shielded-vtpm \
#   --shielded-integrity-monitoring


locals {
  zone-a = "${var.region}-a"
  zone-b = "${var.region}-b"
}

provider "google" {
  region = var.region
}

resource "random_id" "id" {
  byte_length = 4
  prefix      = "sg"
}
