# Azure VM Ansible Role

This role provides comprehensive Azure VM management capabilities including creation, configuration, and lifecycle management.

## Features

- **VM Creation**: Create Azure VMs with customizable configurations
- **Lifecycle Management**: Start, stop, restart, and deallocate VMs
- **Security Configuration**: Configure firewalls, SSH hardening, and security groups
- **Application Setup**: Install and configure Docker, web servers, and databases
- **Monitoring & Backup**: Optional monitoring and backup configuration
- **Cost Optimization**: Auto-shutdown capabilities and resource management

## Requirements

- Ansible >= 2.14
- Azure CLI installed and configured
- Azure Collection: `azure.azcollection >= 1.19.0`
- Python packages: `azure-cli-core`, `azure-mgmt-*`

## Role Variables

### Required Variables

- `vm_name`: Name of the virtual machine
- `azure_subscription_id`: Azure subscription ID (or set via environment)

### Important Optional Variables

```yaml
# VM Configuration
vm_size: "Standard_B2s"
azure_region: "eastus"
vm_admin_username: "azureuser"

# Network Configuration
vnet_address_prefix: "10.0.0.0/16"
subnet_address_prefix: "10.0.1.0/24"
enable_public_ip: true

# Security
allowed_ssh_sources: ["*"]
firewall_enabled: true

# Features
docker_install: false
webserver_install: false
database_install: false
enable_monitoring: false
enable_backup: false
```

See `defaults/main.yml` for a complete list of variables.

## Dependencies

None directly, but the role can integrate with:
- geerlingguy.docker
- geerlingguy.nginx
- geerlingguy.postgresql

## Example Playbook

### Create a VM

```yaml
- hosts: localhost
  roles:
    - role: azure-vm
      vars:
        azure_vm_operation: create
        vm_name: mywebserver
        vm_size: Standard_B2ms
        azure_region: eastus2
        docker_install: true
```

### Configure an existing VM

```yaml
- hosts: mywebserver
  become: true
  roles:
    - role: azure-vm
      vars:
        azure_vm_operation: configure
        webserver_install: true
        enable_ssl: true
```

### Manage VM state

```yaml
- hosts: localhost
  roles:
    - role: azure-vm
      vars:
        azure_vm_operation: stop
        vm_name: mywebserver
```

## Task Files

The role includes specialized task files for different operations:

- `validate.yml`: Validates Azure credentials and requirements
- `prerequisites.yml`: Sets up Azure prerequisites
- `create-vm.yml`: Creates the virtual machine
- `networking.yml`: Configures networking components
- `security.yml`: Implements security hardening
- `manage-vm.yml`: Handles VM state changes
- `configure-vm.yml`: Post-creation configuration
- `docker.yml`: Docker installation and setup
- `webserver.yml`: Web server configuration
- `database.yml`: Database installation
- `monitoring.yml`: Monitoring setup
- `backup.yml`: Backup configuration
- `cleanup.yml`: Resource cleanup
- `report.yml`: Generate operation reports

## Usage with azvm CLI

This role is designed to work with the `azvm` wrapper script:

```bash
# Create a VM
azvm create --name myvm --size Standard_B2s --region eastus

# Configure the VM
azvm setup --name myvm --roles docker,webserver

# Manage VM state
azvm manage --action stop --name myvm
```

## Security Considerations

1. **SSH Keys**: Always use SSH key authentication
2. **Network Security**: Restrict SSH access to known IPs
3. **Updates**: Enable automatic security updates
4. **Firewall**: UFW is enabled by default
5. **Fail2ban**: Can be enabled for brute-force protection

## Resource Tagging

All resources are tagged with:
- Environment
- ManagedBy (Ansible)
- CreatedBy (username)
- Custom tags via `resource_tags`

## Cost Management

- Use appropriate VM sizes
- Enable auto-shutdown for dev/test VMs
- Deallocate VMs when not in use
- Monitor resource usage

## Troubleshooting

1. **Authentication Issues**: Ensure Azure CLI is logged in
2. **Permission Errors**: Check subscription permissions
3. **Network Issues**: Verify NSG rules and connectivity
4. **Module Errors**: Install required collections and dependencies

## Contributing

1. Follow Ansible best practices
2. Test changes thoroughly
3. Update documentation
4. Use meaningful commit messages

## License

This role is part of the dotfiles repository and follows its licensing terms.

## Author

Created for Azure VM automation as part of the dotfiles project.