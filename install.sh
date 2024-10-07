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
DOTFILES_DIR="$HOME/.dotfiles"  
if [ ! -d "$DOTFILES_DIR" ]; then  
    echo "Cloning dotfiles repository..."  
    git clone https://github.com/setuc/dotfiles.git "$DOTFILES_DIR"  
fi  
  
# Navigate to dotfiles directory  
cd "$DOTFILES_DIR" || exit  
  
# Use Stow to symlink configurations  
echo "Stowing configurations..."  
stow -v -R -t ~ bash || { echo "Failed to stow bash"; exit 1; }  
stow -v -R -t ~ bin || { echo "Failed to stow bin"; exit 1; }  
stow -v -R -t ~ oh-my-posh || { echo "Failed to stow oh-my-posh"; exit 1; }  
  
# Source the new .bashrc  
source ~/.bashrc  
  
echo "Dotfiles setup complete!"  
