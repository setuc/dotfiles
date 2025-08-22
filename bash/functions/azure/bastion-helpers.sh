#!/bin/bash
#
# bastion-helpers.sh - Helper functions for Azure Bastion operations
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Establish a Bastion tunnel connection
azvm-bastion-connect() {
    local vm_name="${1:-}"
    local local_port="${2:-2222}"
    
    if [[ -z "$vm_name" ]]; then
        echo -e "${RED}Error:${NC} VM name is required"
        echo "Usage: azvm-bastion-connect <vm-name> [local-port]"
        return 1
    fi
    
    echo -e "${BLUE}Establishing Bastion tunnel to ${vm_name}...${NC}"
    
    # Check if tunnel script exists
    if command -v azvm-bastion-tunnel &> /dev/null; then
        azvm-bastion-tunnel --vm-name "$vm_name" --local-port "$local_port"
    else
        echo -e "${RED}Error:${NC} azvm-bastion-tunnel not found in PATH"
        return 1
    fi
}

# Quick SSH through Bastion tunnel
azvm-bastion-ssh() {
    local vm_name="${1:-}"
    local local_port="${2:-2222}"
    local ssh_user="${3:-azureuser}"
    
    if [[ -z "$vm_name" ]]; then
        echo -e "${RED}Error:${NC} VM name is required"
        echo "Usage: azvm-bastion-ssh <vm-name> [local-port] [ssh-user]"
        return 1
    fi
    
    # Start tunnel in background
    echo -e "${BLUE}Starting Bastion tunnel in background...${NC}"
    azvm-bastion-tunnel --vm-name "$vm_name" --local-port "$local_port" --daemon
    
    # Wait for tunnel to be ready
    echo -e "${BLUE}Waiting for tunnel to be ready...${NC}"
    local attempts=0
    while ! nc -z localhost "$local_port" 2>/dev/null; do
        sleep 1
        ((attempts++))
        if [[ $attempts -gt 30 ]]; then
            echo -e "${RED}Error:${NC} Tunnel failed to establish"
            return 1
        fi
    done
    
    echo -e "${GREEN}Tunnel ready! Connecting via SSH...${NC}"
    ssh -p "$local_port" "$ssh_user@localhost"
}

# List all active Bastion tunnels
azvm-bastion-list() {
    if command -v azvm-bastion-monitor &> /dev/null; then
        azvm-bastion-monitor --all
    else
        echo -e "${YELLOW}Listing active Bastion tunnels...${NC}"
        ps aux | grep -E "az network bastion tunnel" | grep -v grep || echo "No active tunnels found"
    fi
}

# Kill a Bastion tunnel by port or PID
azvm-bastion-kill() {
    local target="${1:-}"
    
    if [[ -z "$target" ]]; then
        echo -e "${RED}Error:${NC} Port or PID is required"
        echo "Usage: azvm-bastion-kill <port|pid>"
        return 1
    fi
    
    if command -v azvm-bastion-monitor &> /dev/null; then
        azvm-bastion-monitor --kill "$target"
    else
        echo -e "${YELLOW}Killing Bastion tunnel...${NC}"
        if [[ "$target" =~ ^[0-9]+$ ]] && [[ $target -lt 65536 ]]; then
            # It's a port - find the process
            local pid=$(lsof -ti:$target 2>/dev/null)
            if [[ -n "$pid" ]]; then
                kill "$pid" && echo -e "${GREEN}Killed tunnel on port $target${NC}"
            else
                echo -e "${RED}No tunnel found on port $target${NC}"
            fi
        else
            # It's a PID
            kill "$target" && echo -e "${GREEN}Killed process $target${NC}"
        fi
    fi
}

# Check Bastion tunnel status
azvm-bastion-status() {
    local port="${1:-}"
    
    if command -v azvm-bastion-monitor &> /dev/null; then
        if [[ -n "$port" ]]; then
            azvm-bastion-monitor --port "$port"
        else
            azvm-bastion-monitor --all
        fi
    else
        echo -e "${YELLOW}Checking Bastion tunnel status...${NC}"
        if [[ -n "$port" ]]; then
            if nc -z localhost "$port" 2>/dev/null; then
                echo -e "${GREEN}Tunnel on port $port is active${NC}"
            else
                echo -e "${RED}No active tunnel on port $port${NC}"
            fi
        else
            azvm-bastion-list
        fi
    fi
}

# Show Bastion logs
azvm-bastion-logs() {
    local log_dir="$HOME/.azvm/bastion-logs"
    
    if command -v azvm-bastion-monitor &> /dev/null; then
        azvm-bastion-monitor --logs
    else
        if [[ -d "$log_dir" ]]; then
            echo -e "${BLUE}Recent Bastion tunnel logs:${NC}"
            ls -t "$log_dir"/*.log 2>/dev/null | head -5 | while read -r log; do
                echo -e "\n${YELLOW}=== $(basename "$log") ===${NC}"
                tail -20 "$log"
            done
        else
            echo -e "${RED}No log directory found at $log_dir${NC}"
        fi
    fi
}

# Clean up stale Bastion connections
azvm-bastion-cleanup() {
    echo -e "${BLUE}Cleaning up stale Bastion connections...${NC}"
    
    if command -v azvm-bastion-monitor &> /dev/null; then
        azvm-bastion-monitor --cleanup
    else
        # Manual cleanup
        local log_dir="$HOME/.azvm/bastion-logs"
        if [[ -d "$log_dir" ]]; then
            find "$log_dir" -name "*.pid" -type f | while read -r pidfile; do
                local pid=$(cat "$pidfile")
                if ! kill -0 "$pid" 2>/dev/null; then
                    rm -f "$pidfile"
                    echo -e "${GREEN}Removed stale PID file: $(basename "$pidfile")${NC}"
                fi
            done
        fi
    fi
}

# Get Bastion information for a resource group
azvm-bastion-info() {
    local resource_group="${1:-}"
    
    if [[ -z "$resource_group" ]]; then
        echo -e "${RED}Error:${NC} Resource group is required"
        echo "Usage: azvm-bastion-info <resource-group>"
        return 1
    fi
    
    echo -e "${BLUE}Getting Bastion information for resource group: $resource_group${NC}"
    
    az network bastion list \
        --resource-group "$resource_group" \
        --output table \
        2>/dev/null || echo -e "${YELLOW}No Bastion hosts found in resource group${NC}"
}

# Create a port forwarding session through Bastion
azvm-bastion-forward() {
    local vm_name="${1:-}"
    local remote_port="${2:-}"
    local local_port="${3:-}"
    
    if [[ -z "$vm_name" ]] || [[ -z "$remote_port" ]]; then
        echo -e "${RED}Error:${NC} VM name and remote port are required"
        echo "Usage: azvm-bastion-forward <vm-name> <remote-port> [local-port]"
        echo "Example: azvm-bastion-forward my-vm 5432 15432"
        return 1
    fi
    
    # Use same port if local port not specified
    local_port="${local_port:-$remote_port}"
    
    echo -e "${BLUE}Setting up port forwarding:${NC}"
    echo -e "  Local port ${local_port} -> VM ${vm_name}:${remote_port}"
    
    # Start tunnel with custom ports
    azvm-bastion-tunnel \
        --vm-name "$vm_name" \
        --resource-port "$remote_port" \
        --local-port "$local_port"
}

# Watch Bastion tunnels in real-time
azvm-bastion-watch() {
    if command -v azvm-bastion-monitor &> /dev/null; then
        azvm-bastion-monitor --watch --all
    else
        echo -e "${YELLOW}Starting Bastion tunnel watch...${NC}"
        watch -n 5 'ps aux | grep -E "az network bastion tunnel" | grep -v grep || echo "No active tunnels"'
    fi
}

# Quick function to test Bastion connectivity
azvm-bastion-test() {
    local resource_group="${1:-}"
    
    if [[ -z "$resource_group" ]]; then
        echo -e "${RED}Error:${NC} Resource group is required"
        echo "Usage: azvm-bastion-test <resource-group>"
        return 1
    fi
    
    echo -e "${BLUE}Testing Bastion connectivity in resource group: $resource_group${NC}"
    
    # Get Bastion name
    local bastion_name=$(az network bastion list \
        --resource-group "$resource_group" \
        --query "[0].name" -o tsv 2>/dev/null)
    
    if [[ -z "$bastion_name" ]]; then
        echo -e "${RED}No Bastion host found in resource group${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Found Bastion: $bastion_name${NC}"
    
    # Check Bastion status
    local status=$(az network bastion show \
        --name "$bastion_name" \
        --resource-group "$resource_group" \
        --query "provisioningState" -o tsv 2>/dev/null)
    
    if [[ "$status" == "Succeeded" ]]; then
        echo -e "${GREEN}Bastion is ready and operational${NC}"
    else
        echo -e "${YELLOW}Bastion status: $status${NC}"
    fi
}

# Export functions for use in other scripts
export -f azvm-bastion-connect
export -f azvm-bastion-ssh
export -f azvm-bastion-list
export -f azvm-bastion-kill
export -f azvm-bastion-status
export -f azvm-bastion-logs
export -f azvm-bastion-cleanup
export -f azvm-bastion-info
export -f azvm-bastion-forward
export -f azvm-bastion-watch
export -f azvm-bastion-test