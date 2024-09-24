# Python-specific aliases
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'
alias activate='source ./venv/bin/activate'

# Conda aliases
alias coa='conda activate'
alias cod='conda deactivate'
alias col='conda env list'

#Azure Conda aliases
alias coap='conda activate azureml_py310_sdkv2'
alias codp='conda deactivate azureml_py310_sdkv2'
alias coatf='conda activate azureml_py38_PT_TF'
alias codtf='conda deactivate azureml_py38_PT_TF'
alias coup='conda env update --file environment.yml --prune'

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias dir='ls -alF'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# Linux Update aliases
alias ups='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean'

# Vim alias
alias vi='vim'

## Other Utilities

# Function to download, verify hash, and install
download_verify_install() {
    if [ "$#" -lt 2 ]; then
        echo "Usage: download_verify_install <URL> <expected_hash> [install_command]"
        return 1
    fi

    local url="$1"
    local expected_hash="$2"
    local install_command="${3:-}"
    local filename=$(basename "$url")

    # Download the file
    wget "$url" -O "$filename"

    # Compute the SHA256 hash of the downloaded file
    local computed_hash=$(sha256sum "$filename" | awk '{print $1}')

    # Compare the hashes
    if [ "$computed_hash" = "$expected_hash" ]; then
        echo -e "\e[32mHash verification successful.\e[0m"
        if [ -n "$install_command" ]; then
            echo "Proceeding with installation."
            # Execute the install command
            eval "$install_command"
        else
            echo "No install command provided. Skipping installation."
        fi
    else
        echo -e "\e[31mHash verification failed. Aborting installation.\e[0m"
        echo "Expected hash: $expected_hash"
        echo "Computed hash: $computed_hash"
        # Remove the downloaded file
        rm "$filename"
        return 1
    fi
}

# Alias for the download_verify_install function
alias dvi='download_verify_install'

