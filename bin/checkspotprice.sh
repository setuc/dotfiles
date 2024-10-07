#!/bin/bash

# Define the regions and VM series as arrays
regions=("southeastasia" "westeurope" "australiaeast")
vm_series=("Standard_D" "Standard_E" "Standard_NC" "Standard_NV")

# Function to fetch and display VM prices
fetch_vm_prices() {
    local region=$1
    local series=$2

    echo "Fetching prices for VM series $series in region $region..."

    # Fetch the spot prices using Azure Retail Prices API
    # Note: Replace 'subscription-id' with your actual Azure subscription ID
    prices=$(curl -s "https://prices.azure.com/api/retail/prices?\$filter=serviceName eq 'Virtual Machines' and armRegionName eq '$region' and skuName eq '$series' ")

    # Parse the JSON response and extract the relevant pricing information
    # Note: jq is a lightweight and flexible command-line JSON processor
    echo "$prices" | jq '.Items[] | {skuName: .skuName, retailPrice: .retailPrice}'
}

# Function to create a VM with spot pricing
create_spot_vm() {
    local region=$1
    local series=$2
    local vm_name=$3

    # Set the max price for the spot VM
    # Note: Replace '-1' with your desired max price or keep it to avoid eviction based on price
    local max_price=-1

    echo "Creating a spot VM named $vm_name in region $region with series $series..."

    # Create the VM with Azure CLI
    az vm create \
        --resource-group myResourceGroup \
        --name "$vm_name" \
        --location "$region" \
        --image UbuntuLTS \
        --size "$series" \
        --priority Spot \
        --max-price "$max_price" \
        --eviction-policy Deallocate \
        --generate-ssh-keys
}

echo "Select a region:"
select region in "${regions[@]}"; do
    case $region in
        "southeastasia"|"westeurope"|"australiaeast")
            break
            ;;
        *)
            echo "Invalid option. Please select a valid region."
            ;;
    esac
done

echo "Select a VM series:"
select series in "${vm_series[@]}"; do
    case $series in
        "Standard_D"|"Standard_E"|"Standard_NC"|"Standard_NV")
            fetch_vm_prices "$region" "$series"
            break
            ;;
        *)
            echo "Invalid option. Please select a valid VM series."
            ;;
    esac
done

# Prompt user for the VM name
read -r -p "Enter the name for the new spot VM: " vm_name

# Create the spot VM
create_spot_vm "$region" "$series" "$vm_name"
