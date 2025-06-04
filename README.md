# Dotfiles
This repository contains my personal dotfiles and configurations for various environments, including local WSL (Windows Subsystem for Linux), Azure Machine Learning Compute Instances, GitHub Codespaces, and remote Linux terminals. The Ansible playbook has been tested across these setups to ensure consistent behavior.

## Directory Structure
.dotfiles/  
├── bash/  
│   ├── .bashrc  
│   ├── .bash_aliases  
│   ├── .bash_exports  
│   ├── .bash_functions  
│   ├── .bash_prompt  
│   ├── aliases/  
│   │   ├── general.aliases  
│   │   ├── git.aliases  
│   │   ├── docker.aliases  
│   │   └── function_aliases.aliases  
│   ├── completions/  
│   │   ├── custom_env_completion.sh  
│   │   ├── git-completion.bash  
│   │   └── docker-completion.bash  
│   ├── functions/  
│   │   ├── prompt/  
│   │   │   └── update_prompt.sh  
│   │   ├── conda/  
│   │   │   └── create_conda_env.sh  
│   │   ├── azure/  
│   │   │   └── create_aml_env.sh  
│   │   └── utilities/  
│   │       ├── download_verify_install.sh  
│   │       └── extract.sh  
│   └── scripts/  
│       └── example_script.sh  
├── bin/  
│   ├── checkPrices.py  
│   ├── checkPrices2.py  
│   ├── enable_storage_key.sh  
│   ├── checkspotprice.sh  
│   └── create_azure_resources.sh  
├── install.sh  
├── oh-my-posh/  
│   └── themes/  
│       └── night-owl.omp.json  
├── setup_linux.sh  
├── setup_windows.sh  
└── README.md  

### Breakdown:
*  bash/: Contains all Bash-related configurations and files.
   * .bashrc: Main Bash configuration file, which sources other configuration files.
   * .bash_aliases: Contains all your aliases, organized by category in the aliases/ directory.
   * .bash_exports: Contains environment variable exports and initializations for tools like NVM, Neovim, and Cargo.
   * .bash_functions: Sources all the functions from the functions/ directory.
   * .bash_prompt: For customizing the shell prompt.
   * aliases/: Contains categorized alias files.
   * completions/: Contains Bash completion scripts.
   * functions/: Contains categorized function scripts, organized into subdirectories.
   * scripts/: Contains scripts that can be sourced or executed directly.
* bin/: Contains executable scripts that are added to your PATH for global access.
* install.sh, setup_linux.sh and setup_windows.sh: Deprecated shell scripts kept for reference.
* oh-my-posh/: Contains oh-my-posh themes and configurations.
* setup.yml: Primary Ansible playbook for setting up the environment.
* README.md: This file.

## Setup Instructions

### Ansible Setup (recommended)
1. Install Ansible (e.g. `sudo apt install ansible`).
2. Clone the repository
```bash
git clone https://github.com/setuc/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```
3. Run the playbook
```bash
ansible-playbook -i localhost, -c local --ask-become-pass setup.yml
```
Run this command as your regular user; the playbook elevates privileges only
when needed for package installation. The `--ask-become-pass` flag prompts for
your sudo password; omit it if you have passwordless sudo.

If you already have a `~/.bashrc` file, Stow may report conflicts. Back it up
before running the playbook:

```bash
mv ~/.bashrc ~/.bashrc.backup
```
Stow can also fail on WSL if you have symlinks like `~/.aws` or `~/.azure`
pointing to Windows paths. Temporarily move those out of the way if you see
`Absolute/relative mismatch` errors.

This playbook installs Oh My Posh into `~/bin`. The directory is created
automatically if it does not already exist.

The setup also installs Astral's `uv` package manager using its official
installation script, which places the binary in `~/.local/bin` by default.

### Legacy Shell Scripts
Legacy scripts (install.sh, setup_linux.sh, setup_windows.sh) are deprecated and kept only for reference.
### Setting Up Oh My Posh
Oh My Posh is initialized in the ```~/.bashrc``` file. The theme used is night-owl.omp.json, located in the ```oh-my-posh/themes/``` directory.

### Conda Initialization
The conda initialization block is automatically added to ```~/.bashrc``` by running conda init. It's important to keep this block in ```~/.bashrc``` because it's managed by Conda and may be updated automatically.


### NVM, Neovim, and Cargo Initializations
 
These initializations are placed in ```~/.bash_exports```, which is sourced by ```~/.bashrc```. This keeps environment variable exports organized in one place.

**Included** in``` ~/.bash_exports```:
   * NVM Initialization: Sets up Node Version Manager and loads bash completion.
   * Neovim Path Addition: Adds Neovim to PATH.
   * Cargo Environment Initialization: Loads Cargo (Rust) environment variables.

## Usage

* **Aliases**: All aliases are organized in the bash/aliases/ directory and are sourced in ~/.bash_aliases.
  * The `uv.aliases` file provides handy shortcuts for Astral's uv package manager, such as `uvs` for `uv sync` and `uvps` for `uv pip sync`.
* **Functions**: Functions are categorized and placed in bash/functions/ and its subdirectories. They are sourced in ~/.bash_functions.
* **Scripts**: Executable scripts are located in the bin/ directory, which is added to your PATH.
Notes

## Using the Ansible Playbook

This repository includes an Ansible playbook that can configure the local machine or a remote host with the provided dotfiles.

### Run Locally

1. Install Ansible
   ```bash
   sudo apt-get update && sudo apt-get install -y ansible
   ```
2. Execute the playbook
   ```bash
   ansible-playbook -i 'localhost,' -c local --ask-become-pass setup.yml
   ```
   The `--ask-become-pass` flag prompts for your sudo password; omit it if you
   have passwordless sudo.

### Run Against Remote Hosts

Specify an inventory file or pass the hosts on the command line:

```bash
ansible-playbook -i inventory ansible/site.yml
```

 
## Additional Configuration

* Git configuration
    ```bash
    git config --global user.name "Your Name"  
    git config --global user.email "your.email@example.com" 
    ```
* Nerd Fonts Installation
installing Nerd Fonts for better terminal icons from https://github.com/ryanoasis/nerd-fonts or https://www.nerdfonts.com/.  

#### TODO plan to wokr with install nerd fonts directly from the terminal. https://github.com/getnf/getnf




## Generic Notes for me to improve
### Linux Fresh Install
    When working through the Azure ML VM, this is how the .bashrc file looked in the end. 
    oh my posh was installed in 
    cd HOME/cloudfiles/code/Users/setuchokshi/
    mkdir bin
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ./bin
    $HOME/cloudfiles/code/Users/setuchokshi/bin

## BashRC in azure.
    export PATH=$PATH:$HOME/cloudfiles/code/Users/setuchokshi/bin
    eval "$(oh-my-posh init bash --config $HOME/.dotfiles/oh-my-posh/.poshthemes/night-owl.omp.json)"
    if [ -f ~/.bash_aliases ]; then source ~/.bash_aliases; fi
    for file in $HOME/.bash_completion.d/*; do source $file; done

