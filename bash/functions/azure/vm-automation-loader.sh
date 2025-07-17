#!/bin/bash

# VM Automation Function Loader
# This script ensures VM automation functions are loaded correctly
# regardless of whether they're being used within dotfiles or standalone

# Determine the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to load VM automation
load_vm_automation() {
    local vm_automation_path="$SCRIPT_DIR/vm-automation.sh"
    
    # Check if VM automation functions are already loaded
    if type azvm_start &> /dev/null; then
        echo "Azure VM automation functions already loaded."
        return 0
    fi
    
    # Load the VM automation functions
    if [[ -f "$vm_automation_path" ]]; then
        source "$vm_automation_path"
        return 0
    else
        echo "Error: Could not find vm-automation.sh at $vm_automation_path" >&2
        return 1
    fi
}

# Function to setup standalone environment
setup_standalone() {
    # Export minimal required functions if not in dotfiles environment
    if ! type azs &> /dev/null && [[ -f "$SCRIPT_DIR/set_azure_subcription.sh" ]]; then
        source "$SCRIPT_DIR/set_azure_subcription.sh"
    fi
    
    # Load VM automation
    load_vm_automation
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being run directly (not sourced)
    echo "Setting up Azure VM automation in standalone mode..."
    setup_standalone
    
    # Show available functions
    echo ""
    echo "Available VM automation functions:"
    echo "  azvm_start      - Start a VM"
    echo "  azvm_stop       - Stop/deallocate a VM"
    echo "  azvm_delete     - Delete a VM"
    echo "  azvm_status     - Check VM status"
    echo "  azvm_get_ip     - Get VM public IP"
    echo "  azvm_ssh        - SSH to a VM"
    echo "  azvm_list       - List all VMs"
    echo "  azvm_ssh_config - Generate SSH config"
    echo ""
    echo "To use these functions in your current shell, run:"
    echo "  source $0"
else
    # Script is being sourced
    load_vm_automation
fi