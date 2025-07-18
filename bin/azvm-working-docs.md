# Azure VM Management Tool - Complete Documentation

## Table of Contents
- [Quick Start](#quick-start)
- [Aliases Reference](#aliases-reference)
- [Authentication](#authentication)
- [Common Operations](#common-operations)
- [Advanced Usage](#advanced-usage)
- [VS Code Integration](#vs-code-integration)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Quick Start

### Connect to a VM (Fastest Way)
```bash
# Using alias - creates tunnel and SSHs automatically
azvmcon --name myvm

# Or with auto-reconnect for long sessions
azvmb --name myvm
```

### Create a New VM with Bastion
```bash
# Using alias
azvmc --name newvm --enable-bastion

# Wait 5-10 minutes for Bastion deployment, then connect
azvmcon --name newvm
```

### Deploy Bastion to Existing VM
```bash
# Check if VM has Bastion
azvms --name existingvm

# If no Bastion, deploy it
azvmbastion --name existingvm

# Wait 5-10 minutes, then connect
azvmcon --name existingvm
```

## Aliases Reference

### Primary VM Management
| Alias | Full Command | Description |
|-------|--------------|-------------|
| `azvm` | `~/bin/azvm-working` | Base command |
| `azvmc` | `azvm create` | Create new VM |
| `azvmd` | `azvm delete` | Delete VM |
| `azvml` | `azvm list` | List all VMs |
| `azvmld` | `azvm list -d` | List VMs with details |
| `azvms` | `azvm status` | Show VM status (includes Bastion info) |
| `azvmstart` | `azvm start` | Start stopped VM |
| `azvmstop` | `azvm stop` | Stop running VM |
| `azvmrestart` | `azvm stop --wait && azvm start --wait` | Restart VM |

### Bastion & Connection
| Alias | Full Command | Description |
|-------|--------------|-------------|
| `azvmcon` | `azvm connect` | Connect via Bastion |
| `azvmb` | `azvm connect --auto-reconnect` | Connect with auto-reconnect |
| `azvmbastion` | `azvm bastion` | Deploy Bastion to existing VM |
| `azvmcode` | `~/bin/azvm-vscode` | Setup VS Code connection |
| `azvmtl` | `azvm tunnel list` | List active tunnels |
| `azvmts` | `azvm tunnel status` | Check tunnel health |
| `azvmtk` | `azvm tunnel kill` | Kill tunnel(s) |

### Legacy Commands (Backward Compatibility)
| Alias | Function | Description |
|-------|----------|-------------|
| `azvmip` | `azvm_get_ip` | Get public IP (old method) |
| `azvmssh` | `azvm_ssh` | Direct SSH without Bastion |
| `azvmcfg` | `azvm_ssh_config` | Generate SSH config |

## Authentication

### How Bastion Connection Works
```
Your Machine → Azure Bastion → Target VM
     ↓              ↓              ↓
Azure AD Auth   Managed by    SSH Key Auth
(az login)      Azure         (~/.ssh/id_ed25519)
```

1. **To Bastion**: Uses your Azure AD credentials from `az login`
2. **To VM**: Uses your SSH key for authentication

## Common Operations

### VM Lifecycle Management

#### Create VM
```bash
# Basic VM
azvmc --name myvm

# VM with Bastion (recommended)
azvmc --name myvm --enable-bastion

# Custom configuration
azvmc --name myvm --size Standard_D8as_v5 --location eastus --disk-size 1024 --enable-bastion
```

#### List and Monitor VMs
```bash
# Quick list
azvml

# Detailed list
azvmld

# Check specific VM (shows Bastion availability)
azvms --name myvm
```

#### Start/Stop/Delete VMs
```bash
# Start VM
azvmstart --name myvm

# Stop VM (deallocates to save costs)
azvmstop --name myvm

# Stop without deallocating (keeps billing)
azvmstop --name myvm --no-deallocate

# Restart VM
azvmrestart --name myvm

# Delete VM
azvmd --name myvm
```

### Bastion Connection Management

#### Connect to VM
```bash
# Method 1: Direct connection (auto SSH)
azvmcon --name myvm

# Method 2: Create tunnel first, SSH later
azvmcon --name myvm --port 2222 --no-ssh
ssh -p 2222 setuc@localhost

# Method 3: Auto-reconnecting tunnel
azvmb --name myvm
```

#### Manage Tunnels
```bash
# List active tunnels
azvmtl

# Check tunnel health
azvmts

# Kill specific tunnel
azvmtk 2222        # by port
azvmtk myvm        # by VM name
azvmtk all         # all tunnels
```

## Advanced Usage

### Working with Multiple VMs
```bash
# Create multiple VMs
for i in {1..3}; do
    azvmc --name "worker-$i" --enable-bastion
done

# Connect to multiple VMs simultaneously
azvmcon --name worker-1 --port 2201 --no-ssh &
azvmcon --name worker-2 --port 2202 --no-ssh &
azvmcon --name worker-3 --port 2203 --no-ssh &

# Check all connections
azvmts
```

### SSH Config Integration
```bash
# After creating tunnel
azvmcon --name myvm --port 2222 --no-ssh

# Add to SSH config
echo "
Host myvm-bastion
    HostName localhost
    Port 2222
    User setuc
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
" >> ~/.ssh/config

# Then use
ssh myvm-bastion
```

## VS Code Integration

### Quick Setup
```bash
# Setup VS Code connection with automatic config
azvmcode myvm --add-config

# Then in VS Code:
# 1. Ctrl+Shift+P → "Remote-SSH: Connect to Host"
# 2. Select: myvm-bastion
```

### Manual Setup
1. Create tunnel: `azvmcon --name myvm --port 2300 --no-ssh`
2. Add SSH config entry (see above)
3. Connect in VS Code using Remote-SSH extension

### Port Forwarding for Development
Once connected in VS Code:
- Forward ports for web apps (e.g., 8080, 3000)
- Access at `http://localhost:8080`
- Run Jupyter notebooks with forwarded ports

## Troubleshooting

### Connection Issues
```bash
# 1. Check VM status
azvms --name myvm

# 2. Verify Bastion is deployed
# Look for "Bastion available" in status output

# 3. Clean up stale tunnels
azvmtk all

# 4. Check logs
cat ~/.azure/logs/myvm-tunnel.log

# 5. Test connection manually
azvmcon --name myvm 2>&1 | tee debug.log
```

### Port Conflicts
```bash
# Use a different port
azvmcon --name myvm --port 2299
```

### Bastion Deployment Issues
```bash
# Check deployment status
az network bastion list -g RESOURCE_GROUP -o table

# If failed, check VNet address space
az network vnet show -g RESOURCE_GROUP -n VNET_NAME --query addressSpace
```

## Best Practices

### Security
1. **Always use Bastion** for production VMs (no public SSH ports)
2. **Use VM-specific SSH keys** with `--new-key` option
3. **Enable auto-reconnect** for stability in production
4. **Clean up tunnels** when done: `azvmtk all`

### Performance
1. **Use dedicated ports** for frequently accessed VMs
2. **Keep workspaces on VM** when using VS Code
3. **Monitor tunnel health** with `azvmts`
4. **Use tmux/screen** for persistent terminal sessions

### Cost Optimization
1. **Stop VMs** when not in use: `azvmstop --name myvm`
2. **Delete unused VMs**: `azvmd --name myvm`
3. **Share Bastion** across multiple VMs in same resource group
4. **Use smaller VM sizes** for development

## Complete Workflow Example

```bash
# 1. Create a development VM with Bastion
azvmc --name dev-vm --size Standard_B2s --enable-bastion

# 2. Wait for deployment (check status)
azvms --name dev-vm

# 3. Connect for terminal work
azvmcon --name dev-vm

# 4. Setup VS Code for development
azvmcode dev-vm --add-config

# 5. When done for the day
azvmstop --name dev-vm

# 6. Next day, resume work
azvmstart --name dev-vm
azvmb --name dev-vm  # auto-reconnect for stability

# 7. Clean up when project is done
azvmd --name dev-vm
```

## Quick Command Reference

```bash
# Most common operations
azvml                    # List VMs
azvms --name vm          # Check VM status
azvmcon --name vm        # Connect to VM
azvmb --name vm          # Connect with auto-reconnect
azvmcode vm --add-config # Setup VS Code
azvmtl                   # List tunnels
azvmtk all              # Kill all tunnels
```