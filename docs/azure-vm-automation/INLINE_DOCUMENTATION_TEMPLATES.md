# Inline Documentation Templates

This document provides standardized templates for documenting code within the Azure VM Automation project. Consistent documentation helps maintain code quality and makes the project easier to understand and maintain.

## Bash Function Documentation Template

### Basic Function Header

```bash
# Function: function_name
# Description: Brief description of what the function does
# Parameters:
#   $1 - parameter_name: Description of first parameter
#   $2 - parameter_name: Description of second parameter (optional)
# Returns:
#   0 - Success
#   1 - General error
#   2 - Specific error condition
# Example:
#   function_name "value1" "value2"
function_name() {
    local param1="$1"
    local param2="${2:-default_value}"
    
    # Implementation here
}
```

### Complex Function with Error Handling

```bash
# Function: create_azure_vm
# Description: Creates an Azure VM with specified configuration and security settings
# 
# Parameters:
#   $1 - vm_name: Name of the virtual machine (required)
#   $2 - resource_group: Resource group name (required)
#   $3 - vm_size: VM size (optional, default: Standard_B2s)
#   $4 - allowed_ips: Comma-separated list of allowed IP ranges (optional)
#
# Global Variables Used:
#   AZURE_SUBSCRIPTION_ID - Azure subscription ID
#   AZURE_DEFAULT_REGION - Default region for resources
#
# Global Variables Set:
#   VM_RESOURCE_ID - Resource ID of created VM
#   VM_PUBLIC_IP - Public IP address of VM
#
# Returns:
#   0 - VM created successfully
#   1 - Missing required parameters
#   2 - Azure CLI error
#   3 - Resource already exists
#
# Side Effects:
#   - Creates Azure VM and associated resources
#   - Outputs VM details to stdout
#   - Logs operations to $LOG_FILE
#
# Example:
#   create_azure_vm "myvm" "myrg" "Standard_D2s_v3" "192.168.1.0/24"
#
# Notes:
#   - Requires Azure CLI to be logged in
#   - VM will be created with managed identity enabled
#   - Network security group will be automatically configured
create_azure_vm() {
    local vm_name="$1"
    local resource_group="$2"
    local vm_size="${3:-Standard_B2s}"
    local allowed_ips="${4:-}"
    
    # Validate parameters
    if [[ -z "$vm_name" ]] || [[ -z "$resource_group" ]]; then
        echo "Error: VM name and resource group are required" >&2
        return 1
    fi
    
    # Implementation here
}
```

## Ansible Task Documentation Template

### Basic Task Documentation

```yaml
# Task: task_description
# Purpose: What this task accomplishes
# Requirements: Any prerequisites
# Variables:
#   - variable_name: Description and expected values
#   - another_variable: Description (optional)
# Tags: [tag1, tag2]
- name: Descriptive task name
  module_name:
    parameter: value
  when: condition
  tags:
    - tag1
    - tag2
```

### Complex Playbook Documentation

```yaml
---
# Playbook: azure_vm_setup.yml
# Description: Complete Azure VM setup with security hardening
# Author: Your Name
# Version: 1.0.0
# Last Modified: 2024-01-20
#
# Requirements:
#   - Azure CLI installed and configured
#   - Ansible azure collection (azure.azcollection)
#   - Valid Azure subscription
#
# Variables Required:
#   - azure_resource_group: Target resource group
#   - azure_vm_name: Name for the VM
#   - azure_admin_username: Admin user for VM
#
# Variables Optional:
#   - azure_vm_size: VM size (default: Standard_B2s)
#   - azure_location: Azure region (default: eastus)
#   - allowed_source_ips: List of allowed IPs (default: current IP)
#
# Usage:
#   ansible-playbook azure_vm_setup.yml -e azure_resource_group=myrg -e azure_vm_name=myvm
#
# Tags:
#   - prereq: Install prerequisites only
#   - vm: VM creation tasks
#   - security: Security hardening tasks
#   - config: Post-deployment configuration

- name: Azure VM Setup and Configuration
  hosts: localhost
  connection: local
  gather_facts: yes
  
  vars:
    # Default values
    azure_vm_size: "Standard_B2s"
    azure_location: "eastus"
    
  tasks:
    # Task: Validate Azure CLI authentication
    # Ensures user is logged into Azure before proceeding
    # Fails fast if not authenticated
    - name: Check Azure CLI authentication
      command: az account show
      register: az_account
      changed_when: false
      failed_when: az_account.rc != 0
      tags:
        - prereq
        - always
```

## Configuration File Documentation Template

### JSON Configuration

```json
{
  "_comment": "Azure VM Configuration Template",
  "_version": "1.0.0",
  "_description": "Default configuration for Azure VM creation",
  
  "vm_defaults": {
    "_comment": "Default values for VM creation",
    "size": "Standard_B2s",
    "os_disk_size_gb": 30,
    "os_disk_type": "Premium_LRS"
  },
  
  "network_config": {
    "_comment": "Network security configuration",
    "allowed_ports": [
      {
        "port": 22,
        "protocol": "tcp",
        "description": "SSH access"
      },
      {
        "port": 443,
        "protocol": "tcp", 
        "description": "HTTPS traffic"
      }
    ],
    "allowed_source_ips": {
      "_comment": "IP ranges allowed to access the VM",
      "_format": "CIDR notation",
      "ranges": [
        "192.168.1.0/24",
        "10.0.0.0/8"
      ]
    }
  }
}
```

### YAML Configuration

```yaml
---
# Azure VM Configuration
# Version: 1.0.0
# Description: Default configuration for Azure VM automation
# 
# This file contains default values that can be overridden
# via environment variables or command-line arguments

# VM Configuration Defaults
vm_defaults:
  # Default VM size - can be overridden with AZURE_VM_SIZE
  size: Standard_B2s
  
  # OS disk configuration
  os_disk:
    size_gb: 30          # Disk size in GB
    type: Premium_LRS    # Disk type (Premium_LRS, Standard_LRS, etc.)
  
  # Default OS image
  image:
    publisher: Canonical
    offer: 0001-com-ubuntu-server-jammy
    sku: 22_04-lts-gen2
    version: latest

# Network Security Configuration
network_security:
  # NSG rules to be applied to VMs
  # Each rule has a priority (100-4096)
  inbound_rules:
    - name: SSH
      priority: 100
      port: 22
      protocol: tcp
      access: allow
      description: "Allow SSH from specified IPs"
      
    - name: HTTPS
      priority: 110
      port: 443
      protocol: tcp
      access: allow
      description: "Allow HTTPS traffic"

# Resource Tagging Strategy
tags:
  # Required tags - these must be provided
  required:
    - owner
    - purpose
    - environment
  
  # Default tag values
  defaults:
    environment: development
    managed_by: azure-vm-automation
    delete_after: 30  # days
```

## Script Header Template

```bash
#!/bin/bash
#
# Script: script_name.sh
# Description: One-line description of script purpose
# Author: Your Name
# Version: 1.0.0
# Date: 2024-01-20
#
# Usage:
#   ./script_name.sh [options] <required_arg>
#
# Options:
#   -h, --help          Show this help message
#   -v, --verbose       Enable verbose output
#   -d, --debug         Enable debug mode
#   -f, --force         Force operation without confirmation
#
# Arguments:
#   required_arg        Description of required argument
#
# Environment Variables:
#   AZURE_SUBSCRIPTION_ID    Azure subscription ID (required)
#   AZURE_DEFAULT_REGION     Default region (optional, default: eastus)
#
# Examples:
#   # Basic usage
#   ./script_name.sh myargument
#
#   # With options
#   ./script_name.sh -v -f myargument
#
# Exit Codes:
#   0 - Success
#   1 - General error
#   2 - Invalid arguments
#   3 - Missing dependencies
#   4 - Azure CLI error
#
# Notes:
#   - Requires Azure CLI version 2.40+
#   - Must be run from project root directory
#

set -euo pipefail  # Exit on error, undefined variable, pipe failure

# Script version
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

## Error Message Template

```bash
# Standard error reporting function
# Usage: error_exit "Error message" [exit_code]
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    
    echo "ERROR: $message" >&2
    echo "Script: $SCRIPT_NAME" >&2
    echo "Location: ${BASH_SOURCE[1]}:${BASH_LINENO[0]}" >&2
    echo "Function: ${FUNCNAME[1]}" >&2
    echo "Exit Code: $exit_code" >&2
    
    exit "$exit_code"
}

# Warning message function
# Usage: warn "Warning message"
warn() {
    echo "WARNING: $1" >&2
}

# Info message function (only shown in verbose mode)
# Usage: info "Information message"
info() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo "INFO: $1"
    fi
}

# Debug message function (only shown in debug mode)
# Usage: debug "Debug message"
debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "DEBUG: $1" >&2
    fi
}
```

## Validation Function Template

```bash
# Function: validate_azure_resource_name
# Description: Validates Azure resource names according to naming rules
# Parameters:
#   $1 - resource_type: Type of resource (vm, rg, storage, etc.)
#   $2 - resource_name: Name to validate
# Returns:
#   0 - Valid name
#   1 - Invalid name
# Example:
#   validate_azure_resource_name "vm" "my-vm-name"
validate_azure_resource_name() {
    local resource_type="$1"
    local resource_name="$2"
    
    # Define naming rules for each resource type
    case "$resource_type" in
        vm)
            # VMs: 1-64 chars, alphanumeric and hyphens
            if [[ ! "$resource_name" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]] || 
               [[ ${#resource_name} -gt 64 ]]; then
                return 1
            fi
            ;;
        storage)
            # Storage: 3-24 chars, lowercase alphanumeric only
            if [[ ! "$resource_name" =~ ^[a-z0-9]{3,24}$ ]]; then
                return 1
            fi
            ;;
        rg)
            # Resource groups: 1-90 chars, alphanumeric, periods, underscores, hyphens
            if [[ ! "$resource_name" =~ ^[a-zA-Z0-9._-]{1,90}$ ]] ||
               [[ "$resource_name" =~ \\.$ ]]; then
                return 1
            fi
            ;;
        *)
            warn "Unknown resource type: $resource_type"
            return 1
            ;;
    esac
    
    return 0
}
```

## API Response Handler Template

```bash
# Function: handle_azure_api_response
# Description: Processes Azure API responses and handles common errors
# Parameters:
#   $1 - response: JSON response from Azure API
#   $2 - operation: Description of operation for error messages
# Returns:
#   0 - Success
#   1 - API error
# Example:
#   handle_azure_api_response "$response" "VM creation"
handle_azure_api_response() {
    local response="$1"
    local operation="$2"
    
    # Check if response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        error_exit "Invalid JSON response during $operation" 1
    fi
    
    # Check for error in response
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        local error_code=$(echo "$response" | jq -r '.error.code // "Unknown"')
        local error_message=$(echo "$response" | jq -r '.error.message // "No message"')
        
        case "$error_code" in
            "AuthorizationFailed")
                error_exit "Authorization failed for $operation. Check your permissions." 2
                ;;
            "ResourceNotFound")
                error_exit "Resource not found during $operation." 3
                ;;
            "QuotaExceeded")
                error_exit "Quota exceeded for $operation. Check your subscription limits." 4
                ;;
            *)
                error_exit "$operation failed: $error_code - $error_message" 1
                ;;
        esac
    fi
    
    return 0
}
```

## Best Practices

1. **Always document**:
   - Function purpose and behavior
   - All parameters and their types
   - Return values and exit codes
   - Side effects and global variables

2. **Use consistent formatting**:
   - Keep documentation close to code
   - Use the same style throughout project
   - Update docs when code changes

3. **Include examples**:
   - Show common usage patterns
   - Demonstrate error cases
   - Provide copy-paste ready examples

4. **Document assumptions**:
   - Required tools and versions
   - Environment setup needed
   - Any prerequisites

5. **Version your documentation**:
   - Include version numbers
   - Document last modified date
   - Note breaking changes