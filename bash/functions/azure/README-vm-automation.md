# Azure VM Automation Functions

This directory contains bash functions for automating Azure VM operations, designed to integrate with both the dotfiles environment and Ansible automation.

## Overview

The VM automation functions provide an interactive command-line interface for managing Azure VMs with features like:
- Interactive VM selection using `fzf`
- VM lifecycle management (start, stop, delete)
- IP address management
- SSH configuration and quick access
- Integration with existing Azure subscription management

## Files

- `vm-automation.sh` - Main functions for VM automation
- `vm-automation-loader.sh` - Compatibility loader for standalone usage
- `set_azure_subcription.sh` - Existing subscription selection function (reused)

## Installation

### Within Dotfiles Environment

If you're using the full dotfiles setup, the functions are automatically loaded through `~/.bash_functions`.

### Standalone Usage

```bash
# Source the loader script
source /path/to/vm-automation-loader.sh

# Or run directly to see available functions
bash /path/to/vm-automation-loader.sh
```

## Prerequisites

Required tools:
- Azure CLI (`az`)
- `jq` for JSON processing
- `fzf` for interactive selection
- SSH client

Install missing tools:
```bash
# macOS
brew install azure-cli jq fzf

# Ubuntu/Debian
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
sudo apt-get install jq fzf

# Arch Linux
yay -S azure-cli jq fzf
```

## Functions Reference

### VM Lifecycle Management

#### `azvm_start [vm_name] [resource_group]`
Start a stopped VM. If no parameters provided, shows interactive selection.

```bash
# Interactive mode
azvm_start

# Direct mode
azvm_start myvm myresourcegroup
```

#### `azvm_stop [vm_name] [resource_group] [deallocate]`
Stop a running VM. Default behavior deallocates (no billing).

```bash
# Interactive mode (deallocates by default)
azvm_stop

# Stop without deallocating (continues billing)
azvm_stop myvm myresourcegroup false
```

#### `azvm_delete [vm_name] [resource_group] [force]`
Delete a VM with confirmation prompt.

```bash
# Interactive mode with confirmation
azvm_delete

# Force delete without confirmation
azvm_delete myvm myresourcegroup true
```

#### `azvm_status [vm_name] [resource_group]`
Check VM status. Shows all VMs if no parameters provided.

```bash
# Show all VMs
azvm_status

# Show specific VM
azvm_status myvm myresourcegroup
```

### IP Management

#### `azvm_get_ip [vm_name] [resource_group]`
Get public IP address of a VM.

```bash
# Interactive selection
azvm_get_ip

# Direct query
azvm_get_ip myvm myresourcegroup
```

#### `azvm_assign_ip <vm_name> <resource_group> [ip_name]`
Create and assign a public IP to a VM.

```bash
azvm_assign_ip myvm myresourcegroup
# Creates IP named "myvm-ip"

azvm_assign_ip myvm myresourcegroup custom-ip-name
```

### SSH Management

#### `azvm_ssh [vm_name] [resource_group] [username]`
Quick SSH connection to a VM (default user: azureuser).

```bash
# Interactive selection
azvm_ssh

# Direct connection
azvm_ssh myvm myresourcegroup

# Custom username
azvm_ssh myvm myresourcegroup customuser
```

#### `azvm_ssh_config [vm_name] [resource_group] [username] [port]`
Generate SSH config entry for a VM.

```bash
# Interactive mode
azvm_ssh_config

# Generate for specific VM
azvm_ssh_config myvm myresourcegroup

# Custom user and port
azvm_ssh_config myvm myresourcegroup customuser 2222
```

### Utility Functions

#### `azvm_list [format]`
List all VMs with optional detailed format.

```bash
# Standard table format
azvm_list

# Detailed information
azvm_list detailed
```

#### `azvm_wait <vm_name> <resource_group> [operation]`
Wait for a VM operation to complete.

```bash
# Wait for VM to be updated
azvm_wait myvm myresourcegroup

# Wait for specific state
azvm_wait myvm myresourcegroup running
azvm_wait myvm myresourcegroup stopped
```

### Ansible Integration

#### `azvm_create_ansible [playbook_path] [inventory]`
Create VM using Ansible playbook (requires Ansible setup).

```bash
# Use default playbook location
azvm_create_ansible

# Custom playbook
azvm_create_ansible /path/to/playbook.yml "localhost,"
```

## Aliases

Quick shortcuts are available in `azure.aliases`:

| Alias | Function | Description |
|-------|----------|-------------|
| `azvms` | `azvm_start` | Start a VM |
| `azvmst` | `azvm_stop` | Stop a VM |
| `azvmd` | `azvm_delete` | Delete a VM |
| `azvmstat` | `azvm_status` | Check status |
| `azvmip` | `azvm_get_ip` | Get public IP |
| `azvmssh` | `azvm_ssh` | SSH to VM |
| `azvmlist` | `azvm_list` | List VMs |
| `azvmlistd` | `azvm_list detailed` | Detailed list |

## Integration with Existing Functions

The VM automation functions integrate with:

1. **Subscription Management** (`azs`): Automatically sources the existing subscription selection function
2. **Color Definitions**: Uses consistent color scheme across all Azure functions
3. **Error Handling**: Consistent error checking and user feedback

## Environment Detection

Functions automatically detect whether they're running:
- Within the dotfiles environment (full feature set)
- Standalone mode (minimal dependencies)

## Examples

### Complete VM Workflow

```bash
# 1. Select Azure subscription
azs "MyProject"

# 2. List existing VMs
azvmlist

# 3. Start a stopped VM (interactive)
azvms

# 4. Get VM IP address
azvmip

# 5. Configure SSH access
azvmcfg

# 6. Connect via SSH
azvmssh

# 7. Stop VM when done
azvmst
```

### Automation Script Example

```bash
#!/bin/bash
# Load VM automation functions
source /path/to/vm-automation-loader.sh

# Start specific VM
azvm_start "dev-vm" "dev-resources"

# Wait for it to be running
azvm_wait "dev-vm" "dev-resources" running

# Get IP and connect
ip=$(azvm_get_ip "dev-vm" "dev-resources" | tail -1)
ssh azureuser@$ip
```

## Troubleshooting

### Missing Commands
If you see errors about missing commands:
```bash
Error: Missing required tools: az jq fzf
```
Install the missing tools as shown in Prerequisites.

### Not Logged In
If you see:
```bash
Error: Not logged into Azure. Please run 'az login' first.
```
Run `az login` or use the `azl` alias.

### No Subscription Selected
Ensure you have a subscription selected:
```bash
azs  # Interactive subscription selection
```

## Future Enhancements

Planned improvements for integration with Ansible automation:
- Automatic VM provisioning from templates
- Batch operations on multiple VMs
- Resource group management
- Network security group configuration
- Backup and snapshot management