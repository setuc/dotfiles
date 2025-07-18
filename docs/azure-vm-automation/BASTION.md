# Azure Bastion SSH Tunnel Guide

This guide covers the Azure Bastion integration with the dotfiles Azure VM automation tools, providing secure SSH access without exposing public IP addresses.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Bastion Deployment](#bastion-deployment)
- [Tunnel Management](#tunnel-management)
- [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
- [Best Practices](#best-practices)
- [Common Issues](#common-issues)

## Overview

Azure Bastion provides secure RDP and SSH connectivity to your virtual machines directly through the Azure portal over TLS. With the native client support, you can also establish SSH tunnels from your local machine.

### Key Features

- **Secure Access**: No public IP required on VMs
- **Native Client Support**: Use your preferred SSH client
- **Port Forwarding**: Forward any TCP port through the tunnel
- **Automatic Reconnection**: Built-in connection monitoring
- **Multi-VM Support**: Manage multiple tunnels simultaneously

## Prerequisites

1. **Azure CLI**: Version 2.32 or later
   ```bash
   az --version
   az extension update --name bastion
   ```

2. **Azure Bastion**: Standard SKU with Native Client Support enabled
3. **Network Configuration**: Proper NSG rules and subnet configuration
4. **Authentication**: Active Azure subscription and login

## Quick Start

### 1. Create VM with Bastion

```bash
# Using azvm-shell script
azvm-shell --name my-vm --bastion

# Using Ansible
ansible-playbook -i inventory.yml playbooks/azure-vm.yml \
  -e vm_name=my-vm \
  -e enable_bastion=true
```

### 2. Connect via Bastion Tunnel

```bash
# Quick connect
azvm-bastion-ssh my-vm

# Manual tunnel with monitoring
azvm-bastion-tunnel --vm-name my-vm --local-port 2222

# In another terminal
ssh -p 2222 azureuser@localhost
```

## Bastion Deployment

### Using azvm-shell Script

The `azvm-shell` script supports Bastion deployment with these options:

```bash
azvm-shell --name <vm-name> --bastion [--bastion-sku Standard]
```

Options:
- `--bastion`: Enable Bastion deployment
- `--bastion-sku`: SKU level (Basic or Standard, default: Standard)

### Using Ansible Playbook

Configure Bastion in your playbook:

```yaml
- hosts: localhost
  roles:
    - role: azure-vm
      vars:
        vm_name: my-secure-vm
        enable_bastion: true
        bastion_sku: Standard
        bastion_enable_tunneling: true
        bastion_enable_ip_connect: true
```

### Manual Deployment

For existing VMs, deploy Bastion manually:

```bash
# Create AzureBastionSubnet
az network vnet subnet create \
  --name AzureBastionSubnet \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --address-prefix 10.0.2.0/26

# Deploy Bastion
az network bastion create \
  --name <bastion-name> \
  --resource-group <rg-name> \
  --vnet-name <vnet-name> \
  --public-ip-address <pip-name> \
  --sku Standard \
  --enable-tunneling true
```

## Tunnel Management

### azvm-bastion-tunnel Command

The main tool for managing Bastion tunnels:

```bash
# Basic usage
azvm-bastion-tunnel --vm-name <vm-name>

# Advanced options
azvm-bastion-tunnel \
  --vm-name my-vm \
  --local-port 3322 \
  --resource-port 22 \
  --timeout 1200000 \
  --debug
```

#### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--vm-name` | Target VM name | Required |
| `--resource-id` | VM resource ID (alternative to name) | - |
| `--target-ip` | Private IP (no AAD auth) | - |
| `--local-port` | Local port to listen on | 2222 |
| `--resource-port` | Target VM port | 22 |
| `--timeout` | Connection timeout (ms) | 600000 |
| `--no-reconnect` | Disable auto-reconnection | false |
| `--daemon` | Run in background | false |
| `--debug` | Enable debug logging | false |

### Helper Functions

Quick functions available after sourcing `bastion-helpers.sh`:

```bash
# Quick SSH connection
azvm-bastion-ssh my-vm

# List active tunnels
azvm-bastion-list

# Check tunnel status
azvm-bastion-status 2222

# Kill tunnel by port
azvm-bastion-kill 2222

# Port forwarding (e.g., PostgreSQL)
azvm-bastion-forward my-vm 5432 15432

# View logs
azvm-bastion-logs
```

## Monitoring and Troubleshooting

### azvm-bastion-monitor Command

Monitor and manage active tunnels:

```bash
# Show all active tunnels
azvm-bastion-monitor --all

# Watch tunnels in real-time
azvm-bastion-monitor --watch --all

# Check specific port
azvm-bastion-monitor --port 2222

# View recent logs
azvm-bastion-monitor --logs

# Clean up stale connections
azvm-bastion-monitor --cleanup
```

### Connection Status Indicators

| Status | Description | Action |
|--------|-------------|--------|
| `active` | Tunnel established and responsive | Normal operation |
| `listening` | Process running, no active connection | Check client connection |
| `running` | Process exists but port not accessible | Check for errors |
| `dead` | Process terminated | Restart required |

### Debug Mode

Enable debug logging for troubleshooting:

```bash
# Start tunnel with debug
azvm-bastion-tunnel --vm-name my-vm --debug

# Check debug logs
tail -f ~/.azvm/bastion-logs/bastion-tunnel-*.log
```

## Best Practices

### 1. Security Configuration

- **NSG Rules**: Ensure proper NSG rules on AzureBastionSubnet
- **SKU Selection**: Use Standard SKU for tunneling support
- **Port Management**: Use non-standard local ports to avoid conflicts

### 2. Connection Management

```bash
# Use daemon mode for long-running connections
azvm-bastion-tunnel --vm-name my-vm --daemon

# Monitor connection health
azvm-bastion-monitor --watch --port 2222
```

### 3. Multiple VMs

```bash
# VM 1 on port 2222
azvm-bastion-tunnel --vm-name vm1 --local-port 2222 --daemon

# VM 2 on port 2223
azvm-bastion-tunnel --vm-name vm2 --local-port 2223 --daemon

# Database forward on port 15432
azvm-bastion-forward db-vm 5432 15432
```

### 4. SSH Config Integration

Add to `~/.ssh/config`:

```
Host my-vm-bastion
    HostName localhost
    Port 2222
    User azureuser
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

Then connect with: `ssh my-vm-bastion`

## Common Issues

### 1. Connection Drops Silently

**Symptom**: Tunnel appears running but connection fails

**Solution**:
```bash
# Enable monitoring with auto-reconnect
azvm-bastion-tunnel --vm-name my-vm --daemon

# Check logs for "Connection to remote host was lost"
azvm-bastion-monitor --logs
```

### 2. Port Already in Use

**Symptom**: Error about port being in use

**Solution**:
```bash
# Find process using port
lsof -ti:2222

# Kill existing tunnel
azvm-bastion-kill 2222

# Use different port
azvm-bastion-tunnel --vm-name my-vm --local-port 3322
```

### 3. Authentication Failures

**Symptom**: Cannot authenticate to VM through tunnel

**Solution**:
- Ensure SSH key is properly configured
- For AAD auth, use resource ID instead of IP
- Check VM allows key-based authentication

### 4. Slow Bastion Deployment

**Symptom**: Bastion creation takes long time

**Solution**:
- Normal deployment time: 5-10 minutes
- Check Azure service health
- Ensure subnet size is at least /26

### 5. Single Connection Limitation

**Symptom**: Only one connection works at a time

**Solution**:
- This is a known limitation
- Use separate tunnels for each connection
- Consider using SSH multiplexing

## Advanced Usage

### Port Forwarding for Services

```bash
# PostgreSQL
azvm-bastion-forward db-vm 5432 15432
psql -h localhost -p 15432 -U dbuser

# Redis
azvm-bastion-forward cache-vm 6379 16379
redis-cli -p 16379

# Custom application
azvm-bastion-forward app-vm 8080 18080
curl http://localhost:18080
```

### Scripted Connections

```bash
#!/bin/bash
# connect-to-prod.sh

# Start tunnel in background
azvm-bastion-tunnel --vm-name prod-vm --daemon

# Wait for tunnel
while ! nc -z localhost 2222; do sleep 1; done

# Execute commands
ssh -p 2222 azureuser@localhost "
  cd /app
  git pull
  systemctl restart app
"

# Cleanup
azvm-bastion-kill 2222
```

### Integration with CI/CD

```yaml
# Azure DevOps Pipeline
- script: |
    # Install CLI
    az extension add --name bastion
    
    # Start tunnel
    az network bastion tunnel \
      --name $(bastionName) \
      --resource-group $(resourceGroup) \
      --target-resource-id $(vmResourceId) \
      --resource-port 22 \
      --port 2222 &
    
    # Wait and deploy
    sleep 10
    ssh -p 2222 deploy@localhost < deploy.sh
```

## Monitoring Script Example

Create a monitoring script for critical connections:

```bash
#!/bin/bash
# monitor-bastion.sh

CRITICAL_VMS=("prod-web" "prod-db" "prod-cache")
ALERT_EMAIL="ops@example.com"

for vm in "${CRITICAL_VMS[@]}"; do
    if ! azvm-bastion-status | grep -q "$vm.*active"; then
        echo "Alert: Bastion tunnel to $vm is down" | \
          mail -s "Bastion Alert: $vm" $ALERT_EMAIL
        
        # Attempt restart
        azvm-bastion-tunnel --vm-name "$vm" --daemon
    fi
done
```

## Cleanup and Maintenance

```bash
# Remove stale connections
azvm-bastion-cleanup

# Remove old logs (older than 7 days)
find ~/.azvm/bastion-logs -name "*.log" -mtime +7 -delete

# Kill all tunnels
ps aux | grep "az network bastion tunnel" | \
  grep -v grep | awk '{print $2}' | xargs kill 2>/dev/null
```

## Additional Resources

- [Azure Bastion Documentation](https://docs.microsoft.com/en-us/azure/bastion/)
- [Azure CLI Bastion Commands](https://docs.microsoft.com/en-us/cli/azure/network/bastion)
- [Network Security Best Practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/network-best-practices)