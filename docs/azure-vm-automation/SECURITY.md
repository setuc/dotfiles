# Security Best Practices for Azure VM Automation

This document outlines security considerations and best practices for the Azure VM automation tools.

## Overview

Security is paramount when automating cloud infrastructure. This guide covers authentication, network security, access control, and operational security practices.

## Authentication & Authorization

### Azure Authentication

1. **Service Principal (Recommended for Automation)**
   ```bash
   # Create service principal
   az ad sp create-for-rbac --name "azvm-automation" \
     --role contributor \
     --scopes /subscriptions/YOUR_SUBSCRIPTION_ID
   
   # Set environment variables
   export AZURE_CLIENT_ID="<appId>"
   export AZURE_SECRET="<password>"
   export AZURE_SUBSCRIPTION_ID="<subscription>"
   export AZURE_TENANT="<tenant>"
   ```

2. **Managed Identity (For Azure-hosted Automation)**
   - Use system-assigned managed identities for VMs running automation
   - No credentials to manage
   - Automatic rotation

3. **Azure CLI Authentication (Development Only)**
   ```bash
   az login
   # Use device code for headless systems
   az login --use-device-code
   ```

### SSH Key Management

1. **Generate Strong Keys**
   ```bash
   ssh-keygen -t ed25519 -C "azvm-automation" -f ~/.ssh/azvm_ed25519
   ssh-keygen -t rsa -b 4096 -C "azvm-automation" -f ~/.ssh/azvm_rsa
   ```

2. **Key Storage**
   - Never commit private keys to repositories
   - Use Azure Key Vault for production keys
   - Rotate keys regularly

3. **SSH Agent Configuration**
   ```bash
   # Add to ~/.bashrc
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/azvm_ed25519
   ```

## Network Security

### Network Security Groups (NSG)

1. **Default Rules (Restrictive)**
   ```yaml
   # In defaults/main.yml
   allowed_ssh_sources:
     - "YOUR_OFFICE_IP/32"
     - "YOUR_VPN_RANGE/24"
   allowed_http_sources:
     - "0.0.0.0/0"  # Only if public web server
   ```

2. **Production NSG Rules**
   ```yaml
   firewall_allowed_ports:
     - port: 22
       protocol: tcp
       source: ["10.0.0.0/8"]  # Internal only
       priority: 100
     - port: 443
       protocol: tcp
       source: ["0.0.0.0/0"]
       priority: 110
   ```

3. **Jump Box Pattern**
   - Create a hardened jump box for SSH access
   - All other VMs only accept SSH from jump box

### Virtual Network Security

1. **Network Isolation**
   - Use separate VNets for different environments
   - Implement network segmentation
   - Use private endpoints for Azure services

2. **VNet Peering**
   ```yaml
   # Example peering configuration
   vnet_peerings:
     - name: prod-to-mgmt
       remote_vnet: /subscriptions/xxx/resourceGroups/rg-mgmt/providers/Microsoft.Network/virtualNetworks/vnet-mgmt
       allow_forwarded_traffic: false
       allow_gateway_transit: false
   ```

## VM Security Hardening

### OS-Level Security

1. **Automatic Updates**
   ```yaml
   # Enabled by default in role
   enable_automatic_updates: true
   update_packages_on_boot: true
   ```

2. **Fail2ban Configuration**
   ```yaml
   # Add to setup playbook
   - name: Configure fail2ban
     template:
       src: fail2ban.jail.local.j2
       dest: /etc/fail2ban/jail.local
     vars:
       fail2ban_maxretry: 3
       fail2ban_bantime: 3600
   ```

3. **Auditd Rules**
   ```yaml
   # Monitor critical files
   - name: Configure audit rules
     lineinfile:
       path: /etc/audit/rules.d/audit.rules
       line: "{{ item }}"
     loop:
       - "-w /etc/passwd -p wa -k passwd_changes"
       - "-w /etc/sudoers -p wa -k sudoers_changes"
       - "-w /var/log/auth.log -p wa -k auth_log"
   ```

### Application Security

1. **Least Privilege**
   - Run services as non-root users
   - Use systemd security features
   - Implement AppArmor/SELinux profiles

2. **Secrets Management**
   ```yaml
   # Use Azure Key Vault
   - name: Retrieve secret from Key Vault
     azure.azcollection.azure_rm_keyvaultsecret_info:
       vault_uri: "https://mykeyvault.vault.azure.net"
       name: "{{ secret_name }}"
     register: secret_result
   ```

## Operational Security

### Logging & Monitoring

1. **Centralized Logging**
   ```yaml
   # Configure rsyslog forwarding
   - name: Configure central logging
     lineinfile:
       path: /etc/rsyslog.conf
       line: "*.* @@{{ syslog_server }}:514"
   ```

2. **Azure Monitor Integration**
   ```yaml
   # Enable diagnostics
   - name: Enable boot diagnostics
     azure.azcollection.azure_rm_virtualmachine:
       name: "{{ vm_name }}"
       boot_diagnostics:
         enabled: true
         storage_account: "{{ diagnostics_storage_account }}"
   ```

3. **Security Alerts**
   - Configure Azure Security Center
   - Set up alert rules for suspicious activities
   - Integrate with SIEM solutions

### Backup & Disaster Recovery

1. **Automated Backups**
   ```yaml
   enable_backup: true
   backup_policy:
     frequency: Daily
     time: "02:00"
     retention_days: 30
   ```

2. **Snapshot Management**
   ```bash
   # Create snapshot before major changes
   az vm create-snapshot --resource-group rg-vm \
     --source vm-disk --name pre-update-snapshot
   ```

## Compliance & Auditing

### Compliance Frameworks

1. **CIS Benchmarks**
   - Implement CIS hardening guidelines
   - Use automated compliance scanning

2. **Azure Policy**
   ```json
   {
     "if": {
       "field": "type",
       "equals": "Microsoft.Compute/virtualMachines"
     },
     "then": {
       "effect": "audit",
       "details": {
         "type": "Microsoft.Compute/virtualMachines/extensions",
         "existenceCondition": {
           "allOf": [{
             "field": "Microsoft.Compute/virtualMachines/extensions/type",
             "equals": "OmsAgentForLinux"
           }]
         }
       }
     }
   }
   ```

### Audit Trail

1. **Change Tracking**
   - Enable Azure Change Tracking
   - Document all changes in commits
   - Maintain runbooks for emergency changes

2. **Access Logs**
   ```yaml
   # Log all sudo commands
   - name: Configure sudo logging
     lineinfile:
       path: /etc/sudoers
       line: "Defaults logfile=/var/log/sudo.log"
   ```

## Incident Response

### Preparation

1. **Incident Response Plan**
   - Document escalation procedures
   - Maintain emergency access procedures
   - Regular drills and updates

2. **Forensics Preparation**
   ```yaml
   # Preserve logs
   - name: Configure log retention
     lineinfile:
       path: /etc/logrotate.conf
       regexp: '^rotate'
       line: 'rotate 52'
   ```

### Response Procedures

1. **Isolation**
   ```bash
   # Emergency VM isolation
   azvm manage --name compromised-vm --action stop
   
   # Remove from network
   az network nic update --resource-group rg-vm \
     --name nic-vm --remove networkSecurityGroup
   ```

2. **Evidence Collection**
   ```bash
   # Create disk snapshot for forensics
   az snapshot create --resource-group rg-forensics \
     --source /subscriptions/xxx/resourceGroups/rg-vm/providers/Microsoft.Compute/disks/vm-osdisk \
     --name forensics-snapshot-$(date +%Y%m%d-%H%M%S)
   ```

## Security Checklist

### Pre-Deployment
- [ ] Review and restrict NSG rules
- [ ] Validate SSH key permissions (600)
- [ ] Confirm service principal permissions
- [ ] Review resource tags for compliance
- [ ] Validate backup configuration

### Post-Deployment
- [ ] Verify OS updates are applied
- [ ] Confirm fail2ban is active
- [ ] Check firewall rules
- [ ] Validate monitoring agents
- [ ] Test backup restoration

### Ongoing
- [ ] Monthly security updates review
- [ ] Quarterly access audit
- [ ] Annual disaster recovery test
- [ ] Regular security scanning
- [ ] Compliance validation

## Tools & Resources

### Security Scanning
```bash
# Lynis security audit
wget https://downloads.cisofy.com/lynis/lynis-3.0.8.tar.gz
tar xvzf lynis-3.0.8.tar.gz
cd lynis && ./lynis audit system

# OpenSCAP compliance scanning
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_cis \
  /usr/share/xml/scap/ssg/content/ssg-ubuntu2004-ds.xml
```

### Azure Security Tools
- Azure Security Center
- Azure Sentinel
- Azure Policy
- Azure Blueprints
- Microsoft Defender for Cloud

## Contact Information

For security concerns or incidents:
1. Internal security team: security@company.com
2. Azure support: https://azure.microsoft.com/support
3. Emergency: Follow incident response plan

## References

- [Azure Security Best Practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns)
- [CIS Azure Benchmarks](https://www.cisecurity.org/benchmark/azure)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)