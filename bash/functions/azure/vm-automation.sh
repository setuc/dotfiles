#!/bin/bash

# Azure VM Automation Functions
# This file provides functions for managing Azure VMs, IPs, and SSH configurations

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Environment detection
_detect_environment() {
    # Check if we're in dotfiles environment
    if [[ -f ~/.bash_functions ]] && [[ -d ~/functions ]]; then
        echo "dotfiles"
    else
        echo "standalone"
    fi
}

# Check for required commands
_check_requirements() {
    local missing_tools=()
    
    for cmd in az jq fzf; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_tools+=("$cmd")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}Error: Missing required tools: ${missing_tools[*]}${NC}" >&2
        echo "Please install the missing tools and try again." >&2
        return 1
    fi
    
    # Check if logged into Azure
    if ! az account show &> /dev/null; then
        echo -e "${RED}Error: Not logged into Azure. Please run 'az login' first.${NC}" >&2
        return 1
    fi
    
    return 0
}

# Source subscription helper if available
if [[ -f ~/functions/azure/set_azure_subcription.sh ]]; then
    source ~/functions/azure/set_azure_subcription.sh
elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/set_azure_subcription.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/set_azure_subcription.sh"
fi

# VM Lifecycle Management Functions

# Start VMs
azvm_start() {
    _check_requirements || return 1
    
    local vm_name="$1"
    local resource_group="$2"
    
    if [[ -z "$vm_name" ]]; then
        # Interactive mode using fzf
        local vm_info
        vm_info=$(az vm list -d --query "[?powerState!='VM running'].{Name:name,ResourceGroup:resourceGroup,State:powerState,Location:location}" -o json | \
                  jq -r '.[] | "\(.Name) \(.ResourceGroup) \(.State) \(.Location)"' | \
                  fzf --prompt="Select VM to start: " --header="NAME RESOURCE_GROUP STATE LOCATION")
        
        if [[ -n "$vm_info" ]]; then
            vm_name=$(echo "$vm_info" | awk '{print $1}')
            resource_group=$(echo "$vm_info" | awk '{print $2}')
        else
            echo "No VM selected."
            return 1
        fi
    fi
    
    echo -e "${YELLOW}Starting VM: $vm_name in resource group: $resource_group${NC}"
    az vm start --name "$vm_name" --resource-group "$resource_group" --no-wait
    echo -e "${GREEN}VM start initiated. Use 'azvm_status $vm_name $resource_group' to check status.${NC}"
}

# Stop VMs
azvm_stop() {
    _check_requirements || return 1
    
    local vm_name="$1"
    local resource_group="$2"
    local deallocate="${3:-true}"
    
    if [[ -z "$vm_name" ]]; then
        # Interactive mode using fzf
        local vm_info
        vm_info=$(az vm list -d --query "[?powerState=='VM running'].{Name:name,ResourceGroup:resourceGroup,State:powerState,Location:location}" -o json | \
                  jq -r '.[] | "\(.Name) \(.ResourceGroup) \(.State) \(.Location)"' | \
                  fzf --prompt="Select VM to stop: " --header="NAME RESOURCE_GROUP STATE LOCATION")
        
        if [[ -n "$vm_info" ]]; then
            vm_name=$(echo "$vm_info" | awk '{print $1}')
            resource_group=$(echo "$vm_info" | awk '{print $2}')
        else
            echo "No VM selected."
            return 1
        fi
    fi
    
    echo -e "${YELLOW}Stopping VM: $vm_name in resource group: $resource_group${NC}"
    if [[ "$deallocate" == "true" ]]; then
        az vm deallocate --name "$vm_name" --resource-group "$resource_group" --no-wait
        echo -e "${GREEN}VM deallocate initiated (will not be billed).${NC}"
    else
        az vm stop --name "$vm_name" --resource-group "$resource_group" --no-wait
        echo -e "${GREEN}VM stop initiated (will continue to be billed).${NC}"
    fi
}

# Delete VMs with confirmation
azvm_delete() {
    _check_requirements || return 1
    
    local vm_name="$1"
    local resource_group="$2"
    local force="${3:-false}"
    
    if [[ -z "$vm_name" ]]; then
        # Interactive mode using fzf
        local vm_info
        vm_info=$(az vm list -d --query "[].{Name:name,ResourceGroup:resourceGroup,State:powerState,Location:location}" -o json | \
                  jq -r '.[] | "\(.Name) \(.ResourceGroup) \(.State) \(.Location)"' | \
                  fzf --prompt="Select VM to delete: " --header="NAME RESOURCE_GROUP STATE LOCATION")
        
        if [[ -n "$vm_info" ]]; then
            vm_name=$(echo "$vm_info" | awk '{print $1}')
            resource_group=$(echo "$vm_info" | awk '{print $2}')
        else
            echo "No VM selected."
            return 1
        fi
    fi
    
    # Show VM details before deletion
    echo -e "${YELLOW}VM Details:${NC}"
    az vm show --name "$vm_name" --resource-group "$resource_group" --query "{Name:name,Location:location,Size:hardwareProfile.vmSize,OS:storageProfile.osDisk.osType}" -o table
    
    if [[ "$force" != "true" ]]; then
        echo -e "${RED}WARNING: This will permanently delete the VM and all associated resources.${NC}"
        read -p "Are you sure you want to delete VM '$vm_name'? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "Deletion cancelled."
            return 1
        fi
    fi
    
    echo -e "${YELLOW}Deleting VM: $vm_name in resource group: $resource_group${NC}"
    az vm delete --name "$vm_name" --resource-group "$resource_group" --yes --no-wait
    echo -e "${GREEN}VM deletion initiated.${NC}"
}

# Get VM status
azvm_status() {
    _check_requirements || return 1
    
    local vm_name="${1:-}"
    local resource_group="${2:-}"
    
    if [[ -z "$vm_name" ]]; then
        # Show all VMs status
        echo -e "${YELLOW}All VMs Status:${NC}"
        az vm list -d --query "[].{Name:name,ResourceGroup:resourceGroup,State:powerState,Location:location,PublicIP:publicIps,PrivateIP:privateIps}" -o table
    else
        # Show specific VM status
        echo -e "${YELLOW}VM Status for: $vm_name${NC}"
        az vm get-instance-view --name "$vm_name" --resource-group "$resource_group" \
           --query "{Name:name,PowerState:instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus|[0],ProvisioningState:provisioningState}" -o table
    fi
}

# IP Management Functions

# Get VM public IP
azvm_get_ip() {
    _check_requirements || return 1
    
    local vm_name="$1"
    local resource_group="$2"
    
    if [[ -z "$vm_name" ]]; then
        # Interactive mode
        local vm_info
        vm_info=$(az vm list -d --query "[?publicIps!=''].{Name:name,ResourceGroup:resourceGroup,PublicIP:publicIps}" -o json | \
                  jq -r '.[] | "\(.Name) \(.ResourceGroup) \(.PublicIP)"' | \
                  fzf --prompt="Select VM: " --header="NAME RESOURCE_GROUP PUBLIC_IP")
        
        if [[ -n "$vm_info" ]]; then
            vm_name=$(echo "$vm_info" | awk '{print $1}')
            resource_group=$(echo "$vm_info" | awk '{print $2}')
        else
            echo "No VM selected."
            return 1
        fi
    fi
    
    local public_ip
    public_ip=$(az vm show -d --name "$vm_name" --resource-group "$resource_group" --query "publicIps" -o tsv)
    
    if [[ -n "$public_ip" ]]; then
        echo -e "${GREEN}Public IP for $vm_name: $public_ip${NC}"
        echo "$public_ip"
    else
        echo -e "${YELLOW}No public IP assigned to $vm_name${NC}"
        return 1
    fi
}

# Assign public IP to VM
azvm_assign_ip() {
    _check_requirements || return 1
    
    local vm_name="${1:-}"
    local resource_group="${2:-}"
    local ip_name="${3:-${vm_name}-ip}"
    
    if [[ -z "$vm_name" || -z "$resource_group" ]]; then
        echo -e "${RED}Usage: azvm_assign_ip <vm_name> <resource_group> [ip_name]${NC}"
        return 1
    fi
    
    # Get VM's NIC
    local nic_id
    nic_id=$(az vm show --name "$vm_name" --resource-group "$resource_group" \
             --query "networkProfile.networkInterfaces[0].id" -o tsv)
    
    if [[ -z "$nic_id" ]]; then
        echo -e "${RED}Could not find network interface for VM $vm_name${NC}"
        return 1
    fi
    
    local nic_name
    nic_name=$(basename "$nic_id")
    
    # Create public IP
    echo -e "${YELLOW}Creating public IP: $ip_name${NC}"
    az network public-ip create \
        --resource-group "$resource_group" \
        --name "$ip_name" \
        --allocation-method Dynamic
    
    # Associate with NIC
    echo -e "${YELLOW}Associating public IP with network interface${NC}"
    az network nic ip-config update \
        --resource-group "$resource_group" \
        --nic-name "$nic_name" \
        --name "ipconfig1" \
        --public-ip-address "$ip_name"
    
    echo -e "${GREEN}Public IP assigned successfully${NC}"
}

# SSH Config Management Functions

# Generate SSH config entry for VM
azvm_ssh_config() {
    _check_requirements || return 1
    
    local vm_name="$1"
    local resource_group="$2"
    local user="${3:-azureuser}"
    local port="${4:-22}"
    
    if [[ -z "$vm_name" ]]; then
        # Interactive mode
        local vm_info
        vm_info=$(az vm list -d --query "[?publicIps!=''].{Name:name,ResourceGroup:resourceGroup,PublicIP:publicIps}" -o json | \
                  jq -r '.[] | "\(.Name) \(.ResourceGroup) \(.PublicIP)"' | \
                  fzf --prompt="Select VM for SSH config: " --header="NAME RESOURCE_GROUP PUBLIC_IP")
        
        if [[ -n "$vm_info" ]]; then
            vm_name=$(echo "$vm_info" | awk '{print $1}')
            resource_group=$(echo "$vm_info" | awk '{print $2}')
        else
            echo "No VM selected."
            return 1
        fi
    fi
    
    local public_ip
    public_ip=$(az vm show -d --name "$vm_name" --resource-group "$resource_group" --query "publicIps" -o tsv)
    
    if [[ -z "$public_ip" ]]; then
        echo -e "${RED}VM $vm_name does not have a public IP${NC}"
        return 1
    fi
    
    local ssh_config="
Host azure-$vm_name
    HostName $public_ip
    User $user
    Port $port
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR"
    
    echo -e "${YELLOW}SSH Config for $vm_name:${NC}"
    echo "$ssh_config"
    
    read -p "Add to ~/.ssh/config? (y/n): " add_config
    if [[ "$add_config" == "y" ]]; then
        echo "$ssh_config" >> ~/.ssh/config
        echo -e "${GREEN}SSH config added. You can now use: ssh azure-$vm_name${NC}"
    fi
}

# Quick SSH to VM
azvm_ssh() {
    _check_requirements || return 1
    
    local vm_name="$1"
    local resource_group="$2"
    local user="${3:-azureuser}"
    
    if [[ -z "$vm_name" ]]; then
        # Interactive mode
        local vm_info
        vm_info=$(az vm list -d --query "[?powerState=='VM running' && publicIps!=''].{Name:name,ResourceGroup:resourceGroup,PublicIP:publicIps}" -o json | \
                  jq -r '.[] | "\(.Name) \(.ResourceGroup) \(.PublicIP)"' | \
                  fzf --prompt="Select VM to SSH: " --header="NAME RESOURCE_GROUP PUBLIC_IP")
        
        if [[ -n "$vm_info" ]]; then
            vm_name=$(echo "$vm_info" | awk '{print $1}')
            resource_group=$(echo "$vm_info" | awk '{print $2}')
        else
            echo "No VM selected."
            return 1
        fi
    fi
    
    local public_ip
    public_ip=$(az vm show -d --name "$vm_name" --resource-group "$resource_group" --query "publicIps" -o tsv)
    
    if [[ -z "$public_ip" ]]; then
        echo -e "${RED}VM $vm_name does not have a public IP${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Connecting to $vm_name at $public_ip...${NC}"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$user@$public_ip"
}

# List all VMs with detailed info
azvm_list() {
    _check_requirements || return 1
    
    local format="${1:-table}"
    
    echo -e "${YELLOW}Azure VMs:${NC}"
    
    if [[ "$format" == "detailed" ]]; then
        az vm list -d --query "[].{Name:name,ResourceGroup:resourceGroup,State:powerState,Location:location,Size:hardwareProfile.vmSize,PublicIP:publicIps,PrivateIP:privateIps,OS:storageProfile.osDisk.osType}" -o table
    else
        az vm list -d -o table
    fi
}

# Helper function to wait for VM operation
azvm_wait() {
    local vm_name="${1:-}"
    local resource_group="${2:-}"
    local operation="${3:-updated}"  # updated, running, stopped, etc.
    
    if [[ -z "$vm_name" || -z "$resource_group" ]]; then
        echo -e "${RED}Usage: azvm_wait <vm_name> <resource_group> [operation]${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Waiting for VM $vm_name to be $operation...${NC}"
    az vm wait --name "$vm_name" --resource-group "$resource_group" --$operation
    echo -e "${GREEN}VM $vm_name is now $operation${NC}"
}

# Create VM from Ansible playbook (stub for integration)
azvm_create_ansible() {
    local playbook_path="${1:-$HOME/.dotfiles/ansible/playbooks/azure-vm-setup.yml}"
    local inventory="${2:-localhost,}"
    
    if [[ ! -f "$playbook_path" ]]; then
        echo -e "${RED}Ansible playbook not found at: $playbook_path${NC}"
        echo "This function requires the Ansible playbook created by the automation setup."
        return 1
    fi
    
    # Check for ansible
    if ! command -v ansible-playbook &> /dev/null; then
        echo -e "${RED}Ansible is not installed. Please install Ansible first.${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Running Ansible playbook to create VM...${NC}"
    ansible-playbook -i "$inventory" "$playbook_path"
}

# Export functions for use in other scripts
export -f azvm_start azvm_stop azvm_delete azvm_status
export -f azvm_get_ip azvm_assign_ip
export -f azvm_ssh_config azvm_ssh
export -f azvm_list azvm_wait
export -f azvm_create_ansible

echo -e "${BLUE}Azure VM automation functions loaded.${NC}"