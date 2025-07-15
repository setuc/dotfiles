#!/bin/bash

# Example: Complete Azure VM Workflow
# This script demonstrates a typical VM management workflow using the automation functions

# Source the VM automation functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../vm-automation-loader.sh"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Azure VM Workflow Example ===${NC}\n"

# Step 1: Check prerequisites
echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"
if _check_requirements; then
    echo -e "${GREEN}✓ All prerequisites met${NC}\n"
else
    echo "Please install missing prerequisites and try again."
    exit 1
fi

# Step 2: Select subscription (if needed)
echo -e "${YELLOW}Step 2: Current Azure subscription:${NC}"
az account show --query "{Name:name, ID:id}" -o table
echo

# Step 3: List existing VMs
echo -e "${YELLOW}Step 3: Listing existing VMs...${NC}"
azvm_list
echo

# Step 4: Interactive VM management menu
while true; do
    echo -e "${YELLOW}What would you like to do?${NC}"
    echo "1) Start a VM"
    echo "2) Stop a VM"
    echo "3) Get VM IP address"
    echo "4) SSH to a VM"
    echo "5) Configure SSH access"
    echo "6) List all VMs (detailed)"
    echo "7) Create new VM (Ansible)"
    echo "8) Exit"
    
    read -p "Select option (1-8): " choice
    echo
    
    case $choice in
        1)
            echo -e "${BLUE}Starting VM...${NC}"
            azvm_start
            ;;
        2)
            echo -e "${BLUE}Stopping VM...${NC}"
            azvm_stop
            ;;
        3)
            echo -e "${BLUE}Getting VM IP...${NC}"
            azvm_get_ip
            ;;
        4)
            echo -e "${BLUE}Connecting to VM...${NC}"
            azvm_ssh
            ;;
        5)
            echo -e "${BLUE}Configuring SSH...${NC}"
            azvm_ssh_config
            ;;
        6)
            echo -e "${BLUE}Detailed VM list:${NC}"
            azvm_list detailed
            ;;
        7)
            echo -e "${BLUE}Creating VM with Ansible...${NC}"
            azvm_create_ansible
            ;;
        8)
            echo -e "${GREEN}Exiting...${NC}"
            break
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
    echo
done

echo -e "${GREEN}Thank you for using Azure VM Automation!${NC}"