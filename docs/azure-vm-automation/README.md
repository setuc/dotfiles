# Azure VM Automation Documentation

This directory contains comprehensive documentation for the Azure VM automation tools integrated into the dotfiles repository.

## Overview

The Azure VM automation provides a unified interface for creating, managing, and configuring Azure Virtual Machines using Ansible. It's designed to be modular and can be extracted into a standalone repository.

## Quick Start

1. **Prerequisites**
   ```bash
   # Install Azure CLI
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   
   # Login to Azure
   az login
   
   # Install Ansible collections
   ansible-galaxy collection install -r ansible/playbooks/azure-vm/requirements.yml
   ```

2. **Create a VM**
   ```bash
   azvm create --name myvm --size Standard_B2s --region eastus
   ```

3. **Manage VM**
   ```bash
   azvm manage --action start --name myvm
   azvm manage --action stop --name myvm
   ```

4. **Setup VM**
   ```bash
   azvm setup --name myvm --roles docker,webserver
   ```

## Components

### 1. CLI Wrapper (`bin/azvm`)
The main command-line interface that wraps Ansible playbooks for ease of use.

**Features:**
- Argument parsing and validation
- Environment variable support
- Help text and usage information
- Error handling and colored output

### 2. Ansible Playbooks
Located in `ansible/playbooks/azure-vm/`:

- **create.yml**: Creates new Azure VMs with networking and security
- **manage.yml**: Manages VM lifecycle (start/stop/restart)
- **setup.yml**: Configures VMs with applications and settings
- **destroy.yml**: Safely removes VMs and associated resources

### 3. Ansible Role
The `azure-vm` role in `ansible/roles/azure-vm/` provides:

- Modular task organization
- Sensible defaults
- OS-specific configurations
- Application installation tasks
- Security hardening

### 4. Inventory Management
Dynamic inventory in `ansible/inventory/azure/vms.yml`:

- Automatically updated when VMs are created/destroyed
- Supports grouping and variables
- Integration with existing Ansible workflows

## Configuration

### Environment Variables

```bash
# Required
export AZURE_SUBSCRIPTION_ID="your-subscription-id"

# Optional - Override default paths
export AZVM_ANSIBLE_PATH="$HOME/.dotfiles/ansible"
export AZVM_INVENTORY_PATH="$AZVM_ANSIBLE_PATH/inventory/azure"
export AZVM_PLAYBOOK_PATH="$AZVM_ANSIBLE_PATH/playbooks/azure-vm"
export AZVM_CONFIG_PATH="$HOME/.config/azvm"
```

### SSH Configuration

Add to `~/.ssh/config`:

```
Host *.cloudapp.azure.com
    User azureuser
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

## Common Use Cases

### 1. Development Environment

```bash
# Create a development VM with common tools
azvm create --name dev-vm --size Standard_B2ms --region eastus
azvm setup --name dev-vm --roles docker
```

### 2. Web Server Deployment

```bash
# Create and configure a web server
azvm create --name web-prod --size Standard_B4ms --region westus2
azvm setup --name web-prod --roles webserver --extra-vars "enable_ssl=true"
```

### 3. Database Server

```bash
# Create a database server
azvm create --name db-prod --size Standard_D4s_v3 --region eastus
azvm setup --name db-prod --roles database --extra-vars "database_type=postgresql"
```

### 4. Cost-Optimized Testing

```bash
# Create VM with auto-shutdown
azvm create --name test-vm --size Standard_B1s \
  --extra-vars "auto_shutdown_enabled=true auto_shutdown_time=19:00"
```

## Architecture

```
┌─────────────────┐
│   azvm CLI      │
└────────┬────────┘
         │
┌────────▼────────┐
│ Ansible Engine  │
└────────┬────────┘
         │
    ┌────┴────┬─────────┬──────────┐
    │         │         │          │
┌───▼──┐ ┌───▼──┐ ┌───▼──┐ ┌─────▼────┐
│Create│ │Manage│ │Setup │ │ Destroy  │
└───┬──┘ └───┬──┘ └───┬──┘ └─────┬────┘
    │         │         │          │
┌───▼─────────▼─────────▼──────────▼───┐
│        Azure Resources               │
│  (VMs, Networks, Storage, etc.)      │
└──────────────────────────────────────┘
```

## Best Practices

1. **Resource Naming**: Use consistent naming conventions
2. **Security**: Always restrict SSH access in production
3. **Cost Management**: Use appropriate VM sizes and enable auto-shutdown
4. **Backup**: Enable backup for production VMs
5. **Monitoring**: Configure monitoring for critical VMs
6. **Documentation**: Document custom configurations

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   ```bash
   az login --tenant YOUR_TENANT_ID
   ```

2. **Module Not Found**
   ```bash
   ansible-galaxy collection install azure.azcollection
   ```

3. **SSH Connection Failed**
   - Check NSG rules
   - Verify public IP assignment
   - Confirm SSH key permissions

4. **Playbook Errors**
   ```bash
   # Run with verbose output
   azvm create --name test -v
   ```

## Integration

### With Existing Dotfiles

The automation integrates with:
- Shell aliases and functions
- SSH configuration
- Git repositories
- Development tools

### CI/CD Pipeline

```yaml
# Example GitHub Actions workflow
- name: Deploy Azure VM
  run: |
    azvm create --name staging-${{ github.sha }} \
      --size Standard_B2s \
      --region eastus
```

## Extending the Automation

### Adding Custom Roles

1. Create role directory:
   ```bash
   mkdir -p ansible/roles/my-custom-role/{tasks,defaults,handlers}
   ```

2. Add to setup playbook:
   ```yaml
   - name: Apply custom role
     include_role:
       name: my-custom-role
     when: "'custom' in vm_roles"
   ```

### Custom Playbooks

Create specialized playbooks in `ansible/playbooks/azure-vm/`:

```yaml
# custom-deploy.yml
- name: Custom Deployment
  hosts: "{{ target_vm }}"
  tasks:
    - name: Your custom tasks
      # ...
```

## Migration Guide

See [MIGRATION.md](MIGRATION.md) for extracting this to a standalone repository.

## Security

See [SECURITY.md](SECURITY.md) for security best practices and considerations.

## Contributing

1. Test changes in a development environment
2. Update documentation
3. Follow Ansible best practices
4. Submit pull requests with clear descriptions

## Resources

- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [Ansible Azure Collection](https://docs.ansible.com/ansible/latest/collections/azure/azcollection/)
- [Azure VM Sizes](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes)
- [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/)

## License

This automation is part of the dotfiles repository and follows its licensing terms.