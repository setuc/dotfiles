# VS Code Remote Development via Azure Bastion

## Quick Start

### Using the Helper Script (Easiest)
```bash
# Setup VS Code connection with automatic config
azvmcode test-bastion-vm --add-config

# Then in VS Code:
# 1. Ctrl+Shift+P → "Remote-SSH: Connect to Host"
# 2. Select: test-bastion-vm-bastion
```

## Manual Setup

### Step 1: Create Bastion Tunnel
```bash
# Create a persistent tunnel on a specific port
azvmcon --name myvm --port 2345 --no-ssh

# Or let it auto-assign a port
azvmcon --name myvm --no-ssh
```

### Step 2: Configure SSH
Add to `~/.ssh/config`:
```ssh
Host myvm-bastion
    HostName localhost
    Port 2345
    User setuc
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

### Step 3: Connect VS Code
1. Install "Remote - SSH" extension
2. `Ctrl+Shift+P` → "Remote-SSH: Connect to Host"
3. Select `myvm-bastion`

## Advanced Features

### Port Forwarding for Web Apps
Once connected in VS Code, you can forward ports:
1. Open Terminal in VS Code
2. `Ctrl+Shift+P` → "Forward a Port"
3. Enter port number (e.g., 8080)
4. Access at `http://localhost:8080`

### Multiple VMs
```bash
# Setup multiple VMs with different ports
azvmcode vm1 --port 2301 --add-config
azvmcode vm2 --port 2302 --add-config
azvmcode vm3 --port 2303 --add-config

# All will be available in VS Code as:
# - vm1-bastion
# - vm2-bastion  
# - vm3-bastion
```

### Auto-Reconnecting Tunnels
For long development sessions:
```bash
# Create auto-reconnecting tunnel
azvmb --name myvm --port 2345 --no-ssh

# Then use in VS Code as usual
```

## Troubleshooting

### Connection Refused
```bash
# Check if tunnel is active
azvmtl

# Restart tunnel if needed
azvmtk 2345
azvmcon --name myvm --port 2345 --no-ssh
```

### VS Code Can't Connect
1. Check tunnel is running: `azvmts`
2. Verify port: `lsof -i :2345`
3. Test SSH manually: `ssh -p 2345 setuc@localhost`

### Performance Tips
- Use auto-reconnect for stability
- Keep VS Code workspace files on the VM
- Use VS Code's port forwarding for web apps
- Consider using tmux/screen for terminal sessions

## Integration with Development Workflows

### Running Jupyter Notebooks
1. Connect VS Code to VM
2. Start Jupyter: `jupyter notebook --no-browser --port=8888`
3. Forward port 8888 in VS Code
4. Access at `http://localhost:8888`

### Docker Development
1. Connect VS Code to VM
2. Install Docker extension
3. Docker commands work seamlessly
4. Forward container ports as needed

### Git Integration
- Git operations work normally
- Use VS Code's built-in Git features
- SSH agent forwarding works automatically

## Best Practices

1. **Dedicated Ports**: Assign specific ports to frequently used VMs
2. **SSH Config**: Use `--add-config` for persistent setup
3. **Auto-reconnect**: Use for long sessions to handle network interruptions
4. **Clean Up**: Kill unused tunnels to free resources

## Example Workflow

```bash
# 1. Deploy Bastion if needed
azvmbastion --name myvm

# 2. Setup VS Code connection
azvmcode myvm --add-config

# 3. Connect in VS Code
# Ctrl+Shift+P → Connect to Host → myvm-bastion

# 4. When done, clean up
azvmtk all
```