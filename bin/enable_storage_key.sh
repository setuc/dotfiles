#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to list storage accounts and their settings
list_storage_accounts() {
    local total_count=0
    local enabled_count=0
    local disabled_count=0

    echo -e "${YELLOW}Current Storage Account Settings:${NC}"
    echo -e "${YELLOW}--------------------------------${NC}"
    for rg in $(az group list --query "[].name" -o tsv); do
        for sa in $(az storage account list --resource-group $rg --query "[].name" -o tsv); do
            allow_shared_key=$(az storage account show --name $sa --resource-group $rg --query "allowSharedKeyAccess" -o tsv)
            if [ "$allow_shared_key" = "true" ]; then
                echo -e "$sa (RG: $rg): Allow storage account key access - ${GREEN}$allow_shared_key${NC}"
                ((enabled_count++))
            else
                echo -e "$sa (RG: $rg): Allow storage account key access - ${RED}$allow_shared_key${NC}"
                ((disabled_count++))
            fi
            ((total_count++))
        done
    done
    echo ""
    echo -e "${YELLOW}Summary:${NC}"
    echo "  Total storage accounts: $total_count"
    echo -e "  Accounts with key access enabled: ${GREEN}$enabled_count${NC}"
    echo -e "  Accounts with key access disabled: ${RED}$disabled_count${NC}"
    echo ""
}

# Function to update a single storage account
update_storage_account() {
    local sa=$1
    local rg=$2
    allow_shared_key=$(az storage account show --name $sa --resource-group $rg --query "allowSharedKeyAccess" -o tsv)
    if [ "$allow_shared_key" = "false" ]; then
        echo -e "Enabling storage account key access for ${YELLOW}$sa${NC} in resource group ${YELLOW}$rg${NC}"
        az storage account update --name $sa --resource-group $rg --allow-shared-key-access true
        echo -e "${GREEN}Storage account key access has been enabled for $sa${NC}"
        return 0
    else
        echo -e "${YELLOW}$sa${NC} already has storage account key access enabled. Skipping."
        return 1
    fi
}

# Function to update all disabled storage accounts
update_all_storage_accounts() {
    local updated_count=0
    local total_count=0
    echo -e "${YELLOW}Updating all disabled storage accounts...${NC}"
    for rg in $(az group list --query "[].name" -o tsv); do
        for sa in $(az storage account list --resource-group $rg --query "[].name" -o tsv); do
            ((total_count++))
            if update_storage_account $sa $rg; then
                ((updated_count++))
            fi
        done
    done
    echo -e "${GREEN}Updated $updated_count out of $total_count storage accounts.${NC}"
}

# List all storage accounts
list_storage_accounts

# Main loop for user interaction
while true; do
    echo -e "${YELLOW}Enter the name of a storage account to update, 'all' to update all disabled accounts, or 'q' to quit:${NC}"
    read input
    if [ "$input" = "q" ]; then
        break
    elif [ "$input" = "all" ]; then
        update_all_storage_accounts
    else
        # Find the resource group for the given storage account
        rg=$(az storage account list --query "[?name=='$input'].resourceGroup" -o tsv)
        if [ -z "$rg" ]; then
            echo -e "${RED}Storage account $input not found. Please try again.${NC}"
        else
            update_storage_account $input $rg
        fi
    fi
    echo ""
done

echo "Exiting. Here's the final state of your storage accounts:"
list_storage_accounts
