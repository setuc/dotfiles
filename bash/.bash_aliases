# Python-specific aliases
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'
alias activate='source ./venv/bin/activate'

# Conda aliases
alias coe='conda activate'
alias cod='conda deactivate'
alias col='conda env list'

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

# Vim alias
alias vi='vim'

## Other Utilities

# Function to download, verify hash, and install
download_verify_install() {
    if [ "$#" -ne 3 ]; then
        echo "Usage: download_verify_install <URL> <expected_hash> <install_command>"
        return 1
    fi

    local url="$1"
    local expected_hash="$2"
    local install_command="$3"
    local filename=$(basename "$url")

    # Download the file
    wget "$url" -O "$filename"

    # Compute the SHA256 hash of the downloaded file
    local computed_hash=$(sha256sum "$filename" | awk '{print $1}')

    # Compare the hashes
    if [ "$computed_hash" = "$expected_hash" ]; then
        echo "Hash verification successful. Proceeding with installation."
        # Execute the install command
        eval "$install_command"
    else
        echo "Hash verification failed. Aborting installation."
        echo "Expected hash: $expected_hash"
        echo "Computed hash: $computed_hash"
        # Remove the downloaded file
        rm "$filename"
        return 1
    fi
}

# Alias for the download_verify_install function
alias dvi='download_verify_install'