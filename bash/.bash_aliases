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

create_conda_env() {
  if [ $# -lt 2 ]; then
    echo "Usage: create_conda_env <env_name> <python_version> [packages/file]"
    return 1
  fi

  env_name=$1
  python_version=$2
  shift 2

  # Create base environment with specified Python version
  conda create -n "$env_name" python="$python_version" -y

  # Activate the new environment
  conda activate "$env_name"

  if [ $# -gt 0 ]; then
    if [ -f "$1" ]; then
      # Check if it's a YAML file
      if [[ "$1" == *.yml ]] || [[ "$1" == *.yaml ]]; then
        conda env update --file "$1"
      # Check if it's a requirements.txt file
      elif [[ "$1" == *requirements.txt ]]; then
        pip install -r "$1"
      else
        echo "Unrecognized file format. Please use .yml, .yaml, or requirements.txt"
      fi
    else
      # Install specified packages
      conda install $@ -y
    fi
  fi

  echo "Environment '$env_name' created with Python $python_version"
  conda list
}

alias coenv='create_conda_env'

# TODO: Seperate out the aliases and the functions into separate file. 

create_aml_env() {
    # Default values
    default_python_version="3.11"
    default_env_name="myenv"
    default_display_name="Python Environment"

    # Prompt for key information
    read -p "Enter environment name (default: $default_env_name): " env_name
    env_name=${env_name:-$default_env_name}

    read -p "Enter display name (default: $default_display_name): " display_name
    display_name=${display_name:-$default_display_name}

    echo "Select Python version:"
    echo "1) 3.10"
    echo "2) 3.11"
    echo "3) 3.12"
    read -p "Enter choice (default: 2 for 3.11): " python_choice
    case $python_choice in
        1) python_version="3.10" ;;
        3) python_version="3.12" ;;
        *) python_version=$default_python_version ;;
    esac

    # Create the environment YAML file
    cat > ${env_name}.yml <<EOL
name: ${env_name}
channels:
  - conda-forge
  - defaults
dependencies:
  - python=${python_version}
  - ipykernel
  - notebook
  - pip
  - pip:
    - azureml-core
EOL

    echo "Environment YAML created. Do you want to add additional packages? (y/n)"
    read add_packages

    if [[ $add_packages == "y" ]]; then
        while true; do
            read -p "Enter package name (or 'done' to finish): " package
            if [[ $package == "done" ]]; then
                break
            fi
            echo "  - $package" >> ${env_name}.yml
        done
    fi

    # Create the environment using conda
    conda env create -f ${env_name}.yml

    # Activate the environment
    conda activate ${env_name}

    # Install the IPython kernel
    python -m ipykernel install --user --name ${env_name} --display-name "${display_name}"

    echo "Environment '${env_name}' created and activated with display name '${display_name}'"
    echo "Python version: ${python_version}"
}

alias azml-env='create_aml_env'
