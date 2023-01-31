#!/bin/bash
AZHOP_CONFIG=config.yml
ANSIBLE_VARIABLES=playbooks/group_vars/all.yml

if [ ! -e $AZHOP_CONFIG ]; then
  echo "$AZHOP_CONFIG doesn't exist, exiting"
  exit 1
fi

rg=$(yq '.resource_group' $AZHOP_CONFIG)

# Purge keyvault
key_vault=$(yq eval '.key_vault' $ANSIBLE_VARIABLES)
if [ "$key_vault" != "" ]; then
  echo "Purging keyvault $key_vault"
    az keyvault purge --name $key_vault
fi

# Remove role assignments for ccportal
ccportal_id=$(az vm show -n ccportal -g $rg --query 'identity.userAssignedIdentities.*.principalId' -o tsv)
if [ "$ccportal_id" != "" ]; then
  echo "Removing role assignments for ccportal"
  az role assignment delete --assignee $ccportal_id
fi

# removing first peer => need to work to do all !!!!
peered_vnet=$(yq ".network.peering[0].vnet_name" $AZHOP_CONFIG)
if [ "$peered_vnet" != "null" ]; then
    peered_vnet_rg=$(yq ".network.peering[0].vnet_resource_group" $AZHOP_CONFIG)
    id=$(az network vnet peering list -g $peered_vnet_rg --vnet-name $peered_vnet --query "[?remoteVirtualNetwork.resourceGroup=='$rg'].id" -o tsv)
    az network vnet peering delete --ids $id
fi