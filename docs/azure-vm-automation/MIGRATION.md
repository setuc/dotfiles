# Migration Guide - Extracting Azure VM Automation

This guide explains how to extract the Azure VM automation from the dotfiles repository into a standalone project.

## Overview

The Azure VM automation is designed to be modular and extractable. This guide walks through the process of creating a standalone repository while maintaining compatibility with the dotfiles structure.

## Prerequisites

- Git installed
- Understanding of the current structure
- Decision on repository location (GitHub, GitLab, etc.)

## Step 1: Prepare the New Repository

### Create Repository Structure

```bash
# Create new repository
mkdir azure-vm-automation
cd azure-vm-automation
git init

# Create directory structure
mkdir -p {ansible/{playbooks,roles,inventory},bin,docs,scripts,tests}

# Create initial files
touch README.md LICENSE .gitignore
```

### .gitignore Template

```gitignore
# Ansible
*.retry
*.pyc
__pycache__/
.ansible/

# Environment
.env
.env.*
!.env.example

# Azure
*.pfx
*.cer
.azure/

# SSH Keys
*.pem
*.key
id_rsa*
id_ed25519*

# Logs
*.log
logs/

# Temporary files
*.tmp
*.swp
*.bak
*~

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.iml

# Terraform (if used)
*.tfstate
*.tfstate.*
.terraform/

# Custom
/inventory/production
/group_vars/production
config/production/
```

## Step 2: Extract Components

### 1. Copy Core Files

```bash
# From dotfiles directory
DOTFILES_DIR="$HOME/.dotfiles"
AZVM_DIR="/path/to/azure-vm-automation"

# Copy Ansible components
cp -r $DOTFILES_DIR/ansible/playbooks/azure-vm $AZVM_DIR/ansible/playbooks/
cp -r $DOTFILES_DIR/ansible/roles/azure-vm $AZVM_DIR/ansible/roles/
cp -r $DOTFILES_DIR/ansible/inventory/azure $AZVM_DIR/ansible/inventory/

# Copy wrapper script
cp $DOTFILES_DIR/bin/azvm $AZVM_DIR/bin/

# Copy documentation
cp -r $DOTFILES_DIR/docs/azure-vm-automation/* $AZVM_DIR/docs/
```

### 2. Update Paths in Scripts

Update `bin/azvm` to use relative paths:

```bash
# Change from:
AZVM_ANSIBLE_PATH="${AZVM_ANSIBLE_PATH:-$HOME/.dotfiles/ansible}"

# To:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AZVM_ANSIBLE_PATH="${AZVM_ANSIBLE_PATH:-$(dirname "$SCRIPT_DIR")/ansible}"
```

### 3. Create Configuration Templates

Create `config/azvm.conf.example`:

```bash
# Azure VM Automation Configuration
# Copy to ~/.config/azvm/azvm.conf and customize

# Azure Settings
AZURE_SUBSCRIPTION_ID=""
AZURE_TENANT_ID=""
AZURE_REGION="eastus"

# Default VM Settings
DEFAULT_VM_SIZE="Standard_B2s"
DEFAULT_ADMIN_USER="azureuser"
DEFAULT_OS_IMAGE="Ubuntu-22.04"

# Network Settings
DEFAULT_VNET_PREFIX="10.0.0.0/16"
DEFAULT_SUBNET_PREFIX="10.0.1.0/24"

# Security Settings
ALLOWED_SSH_SOURCES="0.0.0.0/0"  # Restrict in production!
ENABLE_AUTO_UPDATES="true"
ENABLE_BACKUP="false"

# Paths (usually auto-detected)
# AZVM_ANSIBLE_PATH=""
# AZVM_CONFIG_PATH=""
```

## Step 3: Create Installation Script

Create `install.sh`:

```bash
#!/usr/bin/env bash
#
# Azure VM Automation Installation Script

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Installation directories
INSTALL_DIR="${INSTALL_DIR:-/opt/azure-vm-automation}"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/azvm}"

echo -e "${GREEN}Azure VM Automation Installer${NC}"
echo "=============================="

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    local missing=()
    
    # Check for required commands
    for cmd in git ansible python3 pip3; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}Missing required commands: ${missing[*]}${NC}"
        echo "Please install them first."
        exit 1
    fi
    
    echo -e "${GREEN}✓ All prerequisites met${NC}"
}

# Install Azure CLI
install_azure_cli() {
    if ! command -v az &> /dev/null; then
        echo "Installing Azure CLI..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    else
        echo -e "${GREEN}✓ Azure CLI already installed${NC}"
    fi
}

# Install Ansible collections
install_ansible_collections() {
    echo "Installing Ansible collections..."
    ansible-galaxy collection install -r "$INSTALL_DIR/ansible/playbooks/azure-vm/requirements.yml"
    echo -e "${GREEN}✓ Ansible collections installed${NC}"
}

# Install Python dependencies
install_python_deps() {
    echo "Installing Python dependencies..."
    pip3 install --user azure-cli-core azure-mgmt-compute azure-mgmt-network azure-mgmt-resource
    echo -e "${GREEN}✓ Python dependencies installed${NC}"
}

# Setup configuration
setup_config() {
    echo "Setting up configuration..."
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Copy example config if doesn't exist
    if [ ! -f "$CONFIG_DIR/azvm.conf" ]; then
        cp "$INSTALL_DIR/config/azvm.conf.example" "$CONFIG_DIR/azvm.conf"
        echo -e "${YELLOW}Please edit $CONFIG_DIR/azvm.conf with your Azure settings${NC}"
    fi
    
    echo -e "${GREEN}✓ Configuration setup complete${NC}"
}

# Create symlinks
create_symlinks() {
    echo "Creating symlinks..."
    
    # Symlink the azvm command
    sudo ln -sf "$INSTALL_DIR/bin/azvm" "$BIN_DIR/azvm"
    
    # Make executable
    chmod +x "$INSTALL_DIR/bin/azvm"
    
    echo -e "${GREEN}✓ Symlinks created${NC}"
}

# Setup shell integration
setup_shell_integration() {
    echo "Setting up shell integration..."
    
    # Detect shell
    SHELL_NAME=$(basename "$SHELL")
    SHELL_RC=""
    
    case "$SHELL_NAME" in
        bash) SHELL_RC="$HOME/.bashrc" ;;
        zsh) SHELL_RC="$HOME/.zshrc" ;;
        *) echo "Unsupported shell: $SHELL_NAME"; return ;;
    esac
    
    # Add to shell RC
    if ! grep -q "AZVM_ANSIBLE_PATH" "$SHELL_RC"; then
        cat >> "$SHELL_RC" << EOF

# Azure VM Automation
export AZVM_ANSIBLE_PATH="$INSTALL_DIR/ansible"
export AZVM_CONFIG_PATH="$CONFIG_DIR"
export PATH="\$PATH:$BIN_DIR"
EOF
        echo -e "${GREEN}✓ Added to $SHELL_RC${NC}"
        echo -e "${YELLOW}Please run: source $SHELL_RC${NC}"
    fi
}

# Main installation
main() {
    check_prerequisites
    
    # Clone or copy files
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Installation directory already exists: $INSTALL_DIR${NC}"
        read -p "Remove and reinstall? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo rm -rf "$INSTALL_DIR"
        else
            echo "Aborting installation"
            exit 1
        fi
    fi
    
    # Create installation directory
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown "$USER:$USER" "$INSTALL_DIR"
    
    # Copy files (in real scenario, this would be git clone)
    cp -r ./* "$INSTALL_DIR/"
    
    # Continue with installation
    install_azure_cli
    install_ansible_collections
    install_python_deps
    setup_config
    create_symlinks
    setup_shell_integration
    
    echo
    echo -e "${GREEN}Installation complete!${NC}"
    echo
    echo "Next steps:"
    echo "1. Configure Azure credentials: az login"
    echo "2. Edit configuration: $CONFIG_DIR/azvm.conf"
    echo "3. Run: azvm help"
}

# Run main
main "$@"
```

## Step 4: Create Standalone Documentation

### README.md for Standalone Repository

```markdown
# Azure VM Automation

Automated Azure VM provisioning and management using Ansible.

## Features

- 🚀 Quick VM creation with sensible defaults
- 🔧 Lifecycle management (start/stop/restart)
- 🔒 Security-first approach with hardening
- 📦 Application deployment (Docker, web servers, databases)
- 💰 Cost optimization features
- 📊 Monitoring and backup integration

## Quick Start

### Installation

```bash
git clone https://github.com/yourusername/azure-vm-automation.git
cd azure-vm-automation
./install.sh
```

### Basic Usage

```bash
# Create a VM
azvm create --name myvm --size Standard_B2s --region eastus

# Manage VM
azvm manage --action start --name myvm

# Setup applications
azvm setup --name myvm --roles docker,webserver

# Destroy VM
azvm destroy --name myvm --confirm
```

## Requirements

- Azure subscription
- Azure CLI
- Ansible >= 2.14
- Python >= 3.8

## Documentation

- [User Guide](docs/README.md)
- [Security Guide](docs/SECURITY.md)
- [API Reference](docs/API.md)
- [Contributing](CONTRIBUTING.md)

## License

[Your chosen license]
```

## Step 5: Add Testing Framework

Create `tests/test_azvm.sh`:

```bash
#!/usr/bin/env bash
#
# Test suite for Azure VM Automation

set -euo pipefail

# Test functions
test_cli_help() {
    echo "Testing CLI help..."
    azvm help > /dev/null 2>&1
    assert_success "CLI help command"
}

test_ansible_syntax() {
    echo "Testing Ansible playbook syntax..."
    for playbook in ansible/playbooks/azure-vm/*.yml; do
        ansible-playbook --syntax-check "$playbook"
        assert_success "Syntax check: $playbook"
    done
}

test_role_syntax() {
    echo "Testing Ansible role..."
    ansible-playbook --syntax-check tests/test-role.yml
    assert_success "Role syntax check"
}

# Helper functions
assert_success() {
    if [ $? -eq 0 ]; then
        echo "✓ $1"
    else
        echo "✗ $1"
        exit 1
    fi
}

# Run tests
main() {
    echo "Running Azure VM Automation Tests"
    echo "================================="
    
    test_cli_help
    test_ansible_syntax
    test_role_syntax
    
    echo
    echo "All tests passed!"
}

main "$@"
```

## Step 6: Create CI/CD Pipeline

### GitHub Actions Example

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.x'
        
    - name: Install dependencies
      run: |
        pip install ansible ansible-lint
        ansible-galaxy collection install -r ansible/playbooks/azure-vm/requirements.yml
        
    - name: Lint Ansible
      run: |
        ansible-lint ansible/playbooks/azure-vm/*.yml
        ansible-lint ansible/roles/azure-vm/
        
    - name: Syntax check
      run: |
        for playbook in ansible/playbooks/azure-vm/*.yml; do
          ansible-playbook --syntax-check "$playbook"
        done

  shellcheck:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Run ShellCheck
      uses: ludeeus/action-shellcheck@master
      with:
        scandir: './bin'
        
  test:
    runs-on: ubuntu-latest
    needs: [lint, shellcheck]
    steps:
    - uses: actions/checkout@v3
    
    - name: Run tests
      run: |
        chmod +x tests/test_azvm.sh
        ./tests/test_azvm.sh
```

## Step 7: Package for Distribution

### Create Debian Package

Create `packaging/debian/build-deb.sh`:

```bash
#!/usr/bin/env bash

VERSION="1.0.0"
PACKAGE="azure-vm-automation"

# Create package structure
mkdir -p $PACKAGE/DEBIAN
mkdir -p $PACKAGE/opt/azure-vm-automation
mkdir -p $PACKAGE/usr/local/bin

# Copy files
cp -r ansible bin config docs $PACKAGE/opt/azure-vm-automation/

# Create control file
cat > $PACKAGE/DEBIAN/control << EOF
Package: $PACKAGE
Version: $VERSION
Section: utils
Priority: optional
Architecture: all
Depends: ansible (>= 2.14), python3, python3-pip
Maintainer: Your Name <your.email@example.com>
Description: Azure VM Automation Tool
 Automated Azure VM provisioning and management using Ansible.
EOF

# Create postinst script
cat > $PACKAGE/DEBIAN/postinst << 'EOF'
#!/bin/bash
ln -sf /opt/azure-vm-automation/bin/azvm /usr/local/bin/azvm
chmod +x /opt/azure-vm-automation/bin/azvm
EOF
chmod 755 $PACKAGE/DEBIAN/postinst

# Build package
dpkg-deb --build $PACKAGE
```

## Step 8: Integration with Dotfiles

For users who want to keep integration with dotfiles:

### Create integration script

`scripts/integrate-dotfiles.sh`:

```bash
#!/usr/bin/env bash
#
# Integrate Azure VM Automation with existing dotfiles

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
AZVM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Create symlinks in dotfiles
ln -sf "$AZVM_DIR/bin/azvm" "$DOTFILES_DIR/bin/azvm"
ln -sf "$AZVM_DIR/ansible/playbooks/azure-vm" "$DOTFILES_DIR/ansible/playbooks/azure-vm"
ln -sf "$AZVM_DIR/ansible/roles/azure-vm" "$DOTFILES_DIR/ansible/roles/azure-vm"

echo "Integration complete!"
```

## Migration Checklist

- [ ] Create new repository
- [ ] Copy all files
- [ ] Update paths to be relative
- [ ] Create installation script
- [ ] Add comprehensive README
- [ ] Set up testing framework
- [ ] Configure CI/CD
- [ ] Test standalone installation
- [ ] Create release package
- [ ] Document integration options
- [ ] Tag first release

## Post-Migration

### In Dotfiles Repository

1. Remove Azure VM automation files
2. Add to README:
   ```markdown
   ## Azure VM Automation
   
   The Azure VM automation has been moved to a standalone repository:
   https://github.com/yourusername/azure-vm-automation
   
   To integrate with dotfiles:
   ```bash
   git clone https://github.com/yourusername/azure-vm-automation.git
   cd azure-vm-automation
   ./scripts/integrate-dotfiles.sh
   ```
   ```

### Maintain Compatibility

- Keep environment variable names consistent
- Maintain same CLI interface
- Document any breaking changes
- Provide migration script for existing users

## Support

For issues or questions about migration:
1. Check the [FAQ](docs/FAQ.md)
2. Open an issue in the new repository
3. Contact the maintainers