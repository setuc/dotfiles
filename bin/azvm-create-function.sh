#!/bin/bash

# Replace the handle_create function in azvm with your implementation
handle_create() {
    # Your script's configuration
    local DEFAULT_VM_SIZE="Standard_D4as_v5"
    local DEFAULT_LOCATION="southeastasia"
    local DEFAULT_IMAGE="canonical:ubuntu-24_04-lts:ubuntu-pro:latest"
    local DEFAULT_DISK_SIZE="512"
    local DEFAULT_STORAGE_TYPE="StandardSSD_LRS"
    local DEFAULT_ADMIN_USER="setuc"
    local DEFAULT_SSH_KEY_PATH="$HOME/.ssh/id_ed25519.pub"
    local SSH_CONFIG_FILE="$HOME/.ssh/config"
    
    # Local variables
    local vm_name=""
    local vm_size="$DEFAULT_VM_SIZE"
    local location="$DEFAULT_LOCATION"
    local disk_size="$DEFAULT_DISK_SIZE"
    local new_key=false
    local restrict_ssh=true
    local resource_group=""
    local ssh_key_path="$DEFAULT_SSH_KEY_PATH"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --name)
                vm_name="$2"
                shift 2
                ;;
            --size)
                vm_size="$2"
                shift 2
                ;;
            --location)
                location="$2"
                shift 2
                ;;
            --disk-size)
                disk_size="$2"
                shift 2
                ;;
            --new-key)
                new_key=true
                shift
                ;;
            --no-restrict-ssh)
                restrict_ssh=false
                shift
                ;;
            --resource-group)
                resource_group="$2"
                shift 2
                ;;
            --ssh-key)
                ssh_key_path="$2"
                shift 2
                ;;
            -h|--help)
                cat << EOF
Usage: $SCRIPT_NAME create [options]

Create a new Azure VM with security-first approach

Options:
  --name <name>           VM name (required)
  --size <size>           VM size (default: $DEFAULT_VM_SIZE)
  --location <location>   Azure location (default: $DEFAULT_LOCATION)
  --disk-size <size>      OS disk size in GB (default: $DEFAULT_DISK_SIZE)
  --new-key               Create a new SSH key for this VM
  --no-restrict-ssh       Skip SSH access restriction
  --resource-group <rg>   Resource group name (default: auto-generated)
  --ssh-key <path>        SSH public key path (default: $DEFAULT_SSH_KEY_PATH)
  --help                  Show this help

Examples:
  $SCRIPT_NAME create --name myvm
  $SCRIPT_NAME create --name testvm --new-key
  $SCRIPT_NAME create --name prodvm --size Standard_D8as_v5 --location eastus
  $SCRIPT_NAME create --name openvm --no-restrict-ssh
EOF
                return 0
                ;;
            *)
                error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$vm_name" ]]; then
        error "VM name is required. Use --name <name>"
        return 1
    fi
    
    # Validate VM name format
    if [[ ! "$vm_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,63}$ ]]; then
        error "VM name must start with alphanumeric character and contain only letters, numbers, and hyphens (max 64 chars)"
        return 1
    fi
    
    # Set resource group if not provided
    if [[ -z "$resource_group" ]]; then
        resource_group="${vm_name}_group"
    fi
    
    info "Starting VM creation process..."
    info "VM Name: $vm_name"
    info "Resource Group: $resource_group"
    info "Location: $location"
    info "VM Size: $vm_size"
    
    # Handle SSH key
    if [[ "$new_key" == true ]]; then
        ssh_key_path=$(create_ssh_key "$vm_name")
    else
        check_ssh_key "$ssh_key_path"
    fi
    
    info "Using SSH key: $ssh_key_path"
    
    # Check if logged into Azure
    if ! az account show >/dev/null 2>&1; then
        error "Not logged into Azure. Please run: az login"
        return 1
    fi
    
    # Create resource group if it doesn't exist
    info "Creating resource group if it doesn't exist..."
    az group create --name "$resource_group" --location "$location" --output none
    
    # Prepare tags
    local delete_after=$(get_delete_after_date)
    local tags="Division=GBB/CSA Environment=Development TimeZone=GMT+8 deleteAfter=$delete_after owner=$USER purpose=Auto-created-VM"
    
    # Add custom tags if provided
    if [[ -n "$AZURE_VM_TAGS" ]]; then
        tags="$tags $AZURE_VM_TAGS"
    fi
    
    info "Creating virtual machine..."
    
    # Create VM with all configurations
    az vm create \
        --resource-group "$resource_group" \
        --name "$vm_name" \
        --image "$DEFAULT_IMAGE" \
        --admin-username "$DEFAULT_ADMIN_USER" \
        --ssh-key-values "$ssh_key_path" \
        --size "$vm_size" \
        --location "$location" \
        --os-disk-size-gb "$disk_size" \
        --storage-sku "$DEFAULT_STORAGE_TYPE" \
        --enable-hibernation true \
        --boot-diagnostics-storage "" \
        --authentication-type ssh \
        --tags $tags \
        --output none
    
    success "VM created successfully!"
    
    # Get public IP
    info "Retrieving public IP address..."
    local public_ip=$(az vm show -d -g "$resource_group" -n "$vm_name" --query publicIps -o tsv)
    
    if [[ -z "$public_ip" ]]; then
        warning "No public IP found. The VM might not have a public IP assigned."
        restrict_ssh=false
    else
        success "Public IP: $public_ip"
        
        # Add to SSH config
        add_to_ssh_config "$vm_name" "$public_ip" "$ssh_key_path" "$DEFAULT_ADMIN_USER"
        
        # Restrict SSH access if requested
        if [[ "$restrict_ssh" == true ]]; then
            info "SSH access restriction is enabled"
            
            # Wait for VM to be ready for SSH
            if wait_for_ssh "$vm_name"; then
                # Restrict SSH access to current IP
                restrict_ssh_access "$vm_name" "$resource_group"
            else
                warning "Could not establish SSH connection. Skipping SSH access restriction."
                info "You can manually restrict SSH access later"
            fi
        else
            warning "SSH access restriction is disabled. Your VM is accessible from any IP address."
        fi
    fi
    
    # Show VM details
    info "VM Details:"
    az vm show -d -g "$resource_group" -n "$vm_name" --query "{Name:name, PowerState:powerState, PublicIP:publicIps, PrivateIP:privateIps, Size:hardwareProfile.vmSize}" -o table
    
    success "VM creation completed!"
    
    if [[ -n "$public_ip" ]]; then
        info "Connection: ssh $vm_name"
        if [[ "$restrict_ssh" == true ]]; then
            info "Security: SSH access restricted to your current IP"
            warning "Note: If your IP changes, update the NSG rule in Azure portal"
        else
            warning "Security: SSH access is open to all IPs - consider restricting access"
        fi
    else
        info "Note: VM has no public IP - accessible only within Azure network"
    fi
    
    info "Management commands:"
    info "  Delete VM: az vm delete --resource-group $resource_group --name $vm_name --yes"
    info "  Delete RG: az group delete --name $resource_group --yes"
    info "  Start VM: az vm start --resource-group $resource_group --name $vm_name"
    info "  Stop VM: az vm stop --resource-group $resource_group --name $vm_name"
}

# Helper functions from your script
create_ssh_key() {
    local vm_name=$1
    local key_path="$HOME/.ssh/id_ed25519_${vm_name}"
    
    if [[ -f "$key_path" ]]; then
        warning "SSH key already exists: $key_path"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "$key_path.pub"
            return 0
        fi
    fi
    
    info "Creating new SSH key: $key_path"
    ssh-keygen -t ed25519 -f "$key_path" -N "" -C "azure-vm-$vm_name"
    echo "$key_path.pub"
}

check_ssh_key() {
    local key_path=$1
    if [[ ! -f "$key_path" ]]; then
        error "SSH key not found: $key_path"
        info "You can:"
        info "  1. Create default key: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519"
        info "  2. Use --new-key option to create a VM-specific key"
        return 1
    fi
}

add_to_ssh_config() {
    local vm_name=$1
    local public_ip=$2
    local ssh_key_path=$3
    local username=$4
    
    info "Adding VM to SSH config..."
    
    # Remove existing entry if it exists
    if grep -q "Host $vm_name" "$SSH_CONFIG_FILE" 2>/dev/null; then
        warning "Removing existing SSH config entry for $vm_name"
        sed -i "/Host $vm_name/,/^$/d" "$SSH_CONFIG_FILE"
    fi
    
    # Add new entry
    cat >> "$SSH_CONFIG_FILE" << EOF

Host $vm_name
    HostName $public_ip
    User $username
    IdentityFile ${ssh_key_path%.pub}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ConnectTimeout 10

EOF
    
    success "Added $vm_name to SSH config. You can now connect with: ssh $vm_name"
}

wait_for_ssh() {
    local vm_name=$1
    local max_attempts=30
    local attempt=1
    
    info "Waiting for VM to be ready for SSH connection..."
    
    while [[ $attempt -le $max_attempts ]]; do
        if ssh -o ConnectTimeout=5 -o BatchMode=yes "$vm_name" "echo 'SSH ready'" >/dev/null 2>&1; then
            success "VM is ready for SSH connection"
            return 0
        fi
        
        info "Attempt $attempt/$max_attempts: VM not ready yet, waiting 10 seconds..."
        sleep 10
        ((attempt++))
    done
    
    error "VM did not become ready for SSH within expected time"
    return 1
}

restrict_ssh_access() {
    local vm_name=$1
    local resource_group=$2
    
    info "Getting your source IP address from the VM..."
    
    # Get the source IP from SSH_CONNECTION variable on the VM
    local source_ip
    source_ip=$(ssh "$vm_name" "echo \$SSH_CONNECTION | cut -d' ' -f1" 2>/dev/null)
    
    if [[ -z "$source_ip" ]]; then
        error "Failed to retrieve source IP address from VM"
        return 1
    fi
    
    success "Detected source IP: $source_ip"
    
    # Get the network security group name
    local nsg_name
    nsg_name=$(az vm show --resource-group "$resource_group" --name "$vm_name" \
        --query "networkProfile.networkInterfaces[0].id" -o tsv | \
        xargs -I {} az network nic show --ids {} \
        --query "networkSecurityGroup.id" -o tsv | \
        xargs -I {} basename {})
    
    if [[ -z "$nsg_name" ]]; then
        warning "Could not find Network Security Group. VM might be using subnet-level NSG."
        info "You may need to manually restrict SSH access in the Azure portal"
        return 1
    fi
    
    info "Found Network Security Group: $nsg_name"
    info "Updating SSH rule to allow access only from $source_ip..."
    
    # Update the SSH rule to only allow access from the source IP
    local rule_exists
    rule_exists=$(az network nsg rule list --resource-group "$resource_group" --nsg-name "$nsg_name" \
        --query "[?name=='SSH' || name=='default-allow-ssh'].name" -o tsv)
    
    if [[ -n "$rule_exists" ]]; then
        # Update existing SSH rule
        local rule_name="$rule_exists"
        info "Updating existing SSH rule: $rule_name"
        
        az network nsg rule update \
            --resource-group "$resource_group" \
            --nsg-name "$nsg_name" \
            --name "$rule_name" \
            --source-address-prefixes "$source_ip/32" \
            --output none
    else
        # Create new SSH rule
        info "Creating new SSH rule for restricted access"
        
        az network nsg rule create \
            --resource-group "$resource_group" \
            --nsg-name "$nsg_name" \
            --name "SSH-Restricted" \
            --protocol tcp \
            --priority 1000 \
            --destination-port-range 22 \
            --source-address-prefixes "$source_ip/32" \
            --access allow \
            --output none
    fi
    
    success "SSH access restricted to your IP address: $source_ip"
    warning "Note: If your IP changes, you'll need to update the NSG rule or you'll lose SSH access"
    
    # Show current SSH rules for verification
    info "Current SSH-related NSG rules:"
    az network nsg rule list --resource-group "$resource_group" --nsg-name "$nsg_name" \
        --query "[?destinationPortRange=='22' || destinationPortRange=='*'].{Name:name, SourceIP:sourceAddressPrefix, Priority:priority, Access:access}" \
        -o table
}

get_delete_after_date() {
    if command -v date >/dev/null 2>&1; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            date -v+1y '+%d-%b-%Y'
        else
            # Linux
            date -d '+1 year' '+%d-%b-%Y'
        fi
    else
        echo "31-Dec-2026"
    fi
}