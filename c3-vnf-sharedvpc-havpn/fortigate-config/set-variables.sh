#!/bin/bash
FORTIGATE_EXT_IP=$(terraform output | awk '/FortiGate-extIP/ {print $3}' | tr -d '"')
WEB_HOST_IP=$(terraform output | awk '/host_vm_ip/ {print $3}' | tr -d '"')

sed -i s/FORTIGATE_EXT_IP/$FORTIGATE_EXT_IP/g ./fortigate-config/config.txt
sed -i s/WEB_HOST_IP/$WEB_HOST_IP/g ./fortigate-config/config.txt

echo $FORTIGATE_EXT_IP
echo $WEB_HOST_IP
