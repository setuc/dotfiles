#!/bin/bash  
  
# Function to check if a command exists  
command_exists() {  
    command -v "$1" >/dev/null 2>&1  
}  
  
# Function to install a package if it's not already installed  
install_package() {  
    if ! command_exists "$1"; then  
        echo "Installing $1..."  
        sudo apt-get update && sudo apt-get install -y "$1"  
    else  
        echo "$1 is already installed."  
    fi  
}  
  
# Install Stow  
install_package stow  
  
# Clone dotfiles repository if it doesn't exist  
# Determine the dotfiles directory  
if [ -d ".git" ]; then  
    # Running from the repository directory (CI environment)  
    DOTFILES_DIR="$(pwd)"  
else  
    # Cloning the repository (local environment)  
    DOTFILES_DIR="/tmp/dotfiles"  
    if [ ! -d "$DOTFILES_DIR/.git" ]; then  
        echo "Cloning dotfiles repository..."  
        git clone https://github.com/setuc/dotfiles.git "$DOTFILES_DIR"  
    fi  
    cd "$DOTFILES_DIR" || exit  
fi  
  
# Use Stow to symlink configurations  
echo "Stowing configurations..."  
stow --verbose --restow --dir="$DOTFILES_DIR" --target="$HOME" --stow bash bin oh-my-posh || {  
    echo "Failed to stow configurations"  
    exit 1  
} 
  
# Source the new .bashrc  
source ~/.bashrc  
  
echo "Dotfiles setup complete!"  
