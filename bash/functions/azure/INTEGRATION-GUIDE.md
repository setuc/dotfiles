# Azure VM Automation - Ansible Integration Guide

This guide is for integrating the bash VM automation functions with Ansible playbooks.

## Integration Points

### 1. Function Stubs for Ansible

The `azvm_create_ansible` function in `vm-automation.sh` is a stub that expects:
- Ansible playbook at: `$HOME/.dotfiles/ansible/playbooks/azure-vm-setup.yml`
- Or a custom path provided as parameter

### 2. Expected Ansible Variables

When the Ansible playbook runs, it should expect these environment variables:
```bash
# Set by bash functions
export AZURE_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-rg-automation}"
export AZURE_LOCATION="${AZURE_LOCATION:-eastus}"
```

### 3. VM Naming Convention

The bash functions expect VMs to follow a naming pattern for easy identification:
- Development: `dev-*`
- Production: `prod-*`
- Test: `test-*`

### 4. Required VM Tags

For optimal integration, VMs created by Ansible should include:
```yaml
tags:
  managed_by: "dotfiles-automation"
  created_with: "ansible"
  environment: "{{ env_type }}"
```

### 5. Post-Creation Hook

After Ansible creates a VM, the bash functions can:
1. Automatically detect the new VM with `azvm_list`
2. Configure SSH access with `azvm_ssh_config`
3. Add to local SSH config

### 6. Ansible Callback Integration

The bash functions can be called from Ansible:
```yaml
- name: Configure SSH after VM creation
  shell: |
    source {{ ansible_env.HOME }}/.dotfiles/bash/functions/azure/vm-automation.sh
    azvm_ssh_config "{{ vm_name }}" "{{ resource_group }}"
  args:
    executable: /bin/bash
```

### 7. Shared Configuration

Create a shared config file that both bash and Ansible can read:
```bash
# ~/.dotfiles/config/azure-vm-defaults.conf
DEFAULT_VM_SIZE="Standard_B2s"
DEFAULT_OS_IMAGE="Ubuntu2204"
DEFAULT_ADMIN_USERNAME="azureuser"
DEFAULT_SSH_KEY_PATH="~/.ssh/id_rsa.pub"
```

### 8. Error Handling

The bash functions return specific exit codes:
- 0: Success
- 1: General error
- 2: Missing prerequisites
- 3: Azure authentication error
- 4: Resource not found

Ansible should handle these accordingly.

### 9. Inventory Integration

The bash functions can generate Ansible inventory:
```bash
# Future enhancement
azvm_inventory() {
    az vm list -d --query "[].{
        name:name,
        ansible_host:publicIps,
        ansible_user:'azureuser',
        resource_group:resourceGroup
    }" -o json | jq -r '
    {
        azure_vms: {
            hosts: (. | map({(.name): {
                ansible_host: .ansible_host,
                ansible_user: .ansible_user,
                resource_group: .resource_group
            }}) | add)
        }
    }'
}
```

### 10. Testing Integration

Use the test script to verify integration:
```bash
# Test that Ansible prerequisites are met
bash ~/.dotfiles/bash/functions/azure/test-vm-automation.sh

# Test Ansible playbook detection
azvm_create_ansible --check
```

## Example Workflow

1. **Bash function triggers Ansible:**
   ```bash
   azvm_create_ansible my-custom-playbook.yml
   ```

2. **Ansible creates VM and outputs:**
   ```
   TASK [Display VM details] ***
   ok: [localhost] => {
       "msg": "VM created: myvm-001 (IP: 10.0.0.4)"
   }
   ```

3. **Bash functions automatically configure:**
   ```bash
   # Auto-detect and configure
   azvm_ssh_config myvm-001 my-resource-group
   ```

4. **User connects:**
   ```bash
   azvmssh  # Interactive selection includes new VM
   ```

## Required Ansible Modules

Ensure these are available:
- `azure.azcollection`
- `community.general`

Install with:
```bash
ansible-galaxy collection install azure.azcollection community.general
```

## Environment Variables

Both bash and Ansible should respect:
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_CLIENT_ID` (for service principal)
- `AZURE_SECRET` (for service principal)
- `AZURE_TENANT` (for service principal)

## Debugging

Enable debug output:
```bash
export AZURE_VM_DEBUG=1
```

This will show:
- Azure CLI commands being executed
- Ansible playbook output
- Integration points