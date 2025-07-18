#!/bin/bash
# Deploy Bastion to existing resource group

RESOURCE_GROUP="$1"
if [[ -z "$RESOURCE_GROUP" ]]; then
    echo "Usage: $0 <resource_group>"
    exit 1
fi

# Get VNet name
VNET_NAME=$(az network vnet list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [[ -z "$VNET_NAME" ]]; then
    echo "No VNet found in resource group"
    exit 1
fi

echo "Found VNet: $VNET_NAME"

# Create AzureBastionSubnet
echo "Creating AzureBastionSubnet..."
az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "AzureBastionSubnet" \
    --address-prefixes "10.0.254.0/26" \
    --output none || echo "Subnet exists or address conflict"

# Create public IP
BASTION_NAME="${RESOURCE_GROUP}-bastion"
echo "Creating public IP..."
az network public-ip create \
    --resource-group "$RESOURCE_GROUP" \
    --name "${BASTION_NAME}-pip" \
    --sku Standard \
    --allocation-method Static \
    --output none

# Deploy Bastion
echo "Deploying Bastion (this takes 5-10 minutes)..."
az network bastion create \
    --name "$BASTION_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --public-ip-address "${BASTION_NAME}-pip" \
    --sku Standard \
    --enable-tunneling true \
    --enable-ip-connect true \
    --output none

echo "Bastion deployed! Now you can use:"
echo "./azvm-working connect --name <vm_name>"