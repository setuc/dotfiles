# Dotfiles
This repository contains my personal dotfiles and configurations for various environments, including local WSL (Windows Subsystem for Linux), Azure Machine Learning Compute Instances, GitHub Codespaces, and remote Linux terminals.

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
* install.sh: Script to set up the dotfiles by installing necessary packages and creating symlinks using stow.
* oh-my-posh/: Contains oh-my-posh themes and configurations.
* setup_linux.sh and setup_windows.sh: Setup scripts for Linux and Windows environments, respectively.
* README.md: This file.

## Setup Instructions

### Linux Fresh Install
1. Clone the Repository
   ```bash
   git clone https://github.com/setuc/dotfiles.git ~/.dotfiles  
   ```
2. Navigate to the Directory
   ```bash
   cd ~/.dotfiles  
   ```
3. Make Scripts Executable
   ```bash
   chmod +x install.sh setup_linux.sh
   ```
4. Run the Install Script
   ```bash
   ./install.sh  
   ```
5. Run the Linux Setup Script
   ```bash
   ../setup_linux.sh 
   ```

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
* **Functions**: Functions are categorized and placed in bash/functions/ and its subdirectories. They are sourced in ~/.bash_functions.
* **Scripts**: Executable scripts are located in the bin/ directory, which is added to your PATH.
Notes
 
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

