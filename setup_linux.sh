#!/bin/bash  
  
# Setup script for Linux environment  
  
# Read the software list  
software_list=$(cat software_list.json)  
  
# Update package lists  
sudo apt update  
  
# Install selected software  
for software in $(echo "$software_list" | jq -r 'keys[]'); do  
    description=$(echo "$software_list" | jq -r ".[\"$software\"].description")  
    default=$(echo "$software_list" | jq -r ".[\"$software\"].default")  
    apt_package=$(echo "$software_list" | jq -r ".[\"$software\"].apt")  
    custom_install=$(echo "$software_list" | jq -r ".[\"$software\"].custom_install // empty")  
  
    if prompt_for_installation "$software" "$description" "$default"; then  
        echo "Installing $software..."  
        if [ "$apt_package" != "custom" ]; then  
            sudo apt install -y $apt_package  
        elif [ -n "$custom_install" ]; then  
            eval "$custom_install"  
        else  
            echo "Error: No installation method specified for $software"  
        fi  
    fi  
done  
  
# Install Stow if not already installed  
install_package stow  
  
# Clone dotfiles and stow configurations  
cd "$HOME/.dotfiles" || exit  
stow -v -R -t ~ bash  
stow -v -R -t ~ bin  
stow -v -R -t ~ oh-my-posh  
  
# Update .bashrc if necessary  
if ! grep -q "source ~/.bash_aliases" "$HOME/.bashrc"; then  
    echo 'if [ -f ~/.bash_aliases ]; then source ~/.bash_aliases; fi' >> "$HOME/.bashrc"  
fi  
  
echo "Linux setup complete!"  
