#!/bin/bash

# Setup script for Linux environment using apt and JSON list

# Function to prompt user for installation
prompt_for_installation() {
    local name=$1
    local description=$2
    local default=$3
    if [ "$default" = true ]; then
        local prompt="Y/n"
        local default_answer="Y"
    else
        local prompt="y/N"
        local default_answer="N"
    fi
    read -p "Install $name ($description)? [$prompt] " choice
    choice=${choice:-$default_answer}
    case "$choice" in
        y|Y ) return 0 ;;
        * ) return 1 ;;
    esac
}

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
if prompt_for_installation "Stow" "Symlink farm manager" true; then
    sudo apt install -y stow
fi

# Install Miniconda
if prompt_for_installation "Miniconda" "Minimal conda installer" true; then
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p $HOME/miniconda
    rm miniconda.sh
    echo 'export PATH="$HOME/miniconda/bin:$PATH"' >> $HOME/.bashrc
    source $HOME/.bashrc
fi

# Setup dotfiles
mkdir -p $HOME/.dotfiles
git clone https://github.com/setuc/dotfiles.git $HOME/.dotfiles
cd $HOME/.dotfiles

# Use stow to symlink configurations
stow -v -R -t ~ bash
stow -v -R -t ~ oh-my-posh

# Update .bashrc
echo 'export PATH=$PATH:$HOME/.local/bin' >> $HOME/.bashrc
echo 'eval "$(oh-my-posh init bash --config $HOME/.dotfiles/oh-my-posh/.poshthemes/night-owl.omp.json)"' >> $HOME/.bashrc
echo 'export PATH=$PATH:$HOME/bin' >> $HOME/.bashrc

# Source .bash_aliases (only if it's not already sourced in .bashrc)
if ! grep -q "source ~/.bash_aliases" $HOME/.bashrc; then
    echo 'if [ -f ~/.bash_aliases ]; then source ~/.bash_aliases; fi' >> $HOME/.bashrc
fi

# Setup bash completion scripts
mkdir -p $HOME/.bash_completion.d
cp $HOME/.dotfiles/bash_completion/* $HOME/.bash_completion.d/
echo 'for file in $HOME/.bash_completion.d/*; do source $file; done' >> $HOME/.bashrc

echo "Linux setup complete!"