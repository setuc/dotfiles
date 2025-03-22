#!/usr/bin/env bash
#
# bootstrap.sh - Single script to install dotfiles on Linux.
# -----------------------------------------------
# Features:
#   - Color-coded prompts & output
#   - (Optional) remove old dotfiles
#   - Install stow
#   - Install oh-my-posh
#   - (Optional) install Miniconda
#   - (Optional) install Node (via apt or nvm)
#   - Symlink your dotfiles with stow
#   - Source ~/.bashrc
#
# Usage:
#   1. git clone <your-dotfiles-repo> && cd dotfiles
#   2. chmod +x bootstrap.sh
#   3. ./bootstrap.sh
#

set -euo pipefail

#-------------------------------------
# 0) Color codes
#-------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'  # No Color

#-------------------------------------
# 1) Check if running in CI mode
#-------------------------------------
CI_MODE="${CI:-false}"
if [[ "$CI_MODE" =~ ^(true|1)$ ]]; then
  echo -e "${YELLOW}Detected CI=true; running non-interactively.${NC}"
  NONINTERACTIVE="true"
else
  NONINTERACTIVE="false"
fi

#-------------------------------------
# 2) Helper functions
#-------------------------------------
confirm() {
  # Usage: confirm "message" [default=Y/N]
  local message="$1"
  local default="${2:-N}"

  if [[ "$NONINTERACTIVE" == "true" ]]; then
    # If we are in CI, automatically accept if default=Y
    [[ "$default" =~ ^[Yy]$ ]] && return 0 || return 1
  fi

  local prompt="[y/N]"
  if [[ "$default" =~ ^[Yy]$ ]]; then
    prompt="[Y/n]"
  fi

  echo -en "${YELLOW}${message} ${prompt} ${NC}"
  read -r userinput
  userinput="${userinput:-$default}"

  case "$userinput" in
    [Yy]* ) return 0 ;;
    * ) return 1 ;;
  esac
}

command_exists() {
  command -v "$1" &>/dev/null
}

install_apt_pkg_if_needed() {
  local pkg="$1"
  if ! dpkg -s "$pkg" &>/dev/null; then
    echo -e "${GREEN}Installing $pkg via apt...${NC}"
    sudo apt-get update -y
    sudo apt-get install -y "$pkg"
  else
    echo -e "${GREEN}$pkg is already installed.${NC}"
  fi
}

#-------------------------------------
# 3) Possibly remove existing dotfiles
#-------------------------------------
maybe_remove_old_dotfiles() {
  local files=(.bashrc .bash_aliases .bash_exports .bash_functions .bash_prompt)
  echo -e "${YELLOW}Dotfiles will be symlinked to your home directory.${NC}"
  echo "If you have existing config files, they might conflict."

  if confirm "Remove existing ~/.bashrc, ~/.bash_aliases, etc.?" "N"; then
    for f in "${files[@]}"; do
      if [[ -f "$HOME/$f" || -L "$HOME/$f" ]]; then
        rm -f "$HOME/$f"
        echo -e "  Removed ${f}"
      fi
    done
  else
    echo -e "${YELLOW}Skipping removal of existing dotfiles.${NC}"
  fi
}

#-------------------------------------
# 4) Install stow
#-------------------------------------
install_stow() {
  install_apt_pkg_if_needed stow
}

#-------------------------------------
# 5) Install oh-my-posh (if missing)
#-------------------------------------
install_oh_my_posh() {
  if command_exists oh-my-posh; then
    echo -e "${GREEN}oh-my-posh is already installed.${NC}"
    return
  fi

  echo -e "${GREEN}Installing oh-my-posh...${NC}"
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/bin"

  # Because oh-my-posh was installed into ~/bin, ensure it's on the PATH
  if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bash_exports" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bash_exports"
  fi
}

#-------------------------------------
# 6) (Optional) Install conda
#-------------------------------------
install_miniconda() {
  if command_exists conda; then
    echo -e "${GREEN}conda is already installed.${NC}"
    return
  fi

  echo -e "${GREEN}Installing Miniconda...${NC}"
  local MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
  local installer="miniconda.sh"

  wget -qO "$installer" "$MINICONDA_URL"
  bash "$installer" -b -p "$HOME/miniconda3"
  rm -f "$installer"

  # Init in .bashrc
  "$HOME/miniconda3/bin/conda" init bash
  echo -e "${GREEN}Miniconda installed. Reload shell or 'source ~/.bashrc' to use conda.${NC}"
}

#-------------------------------------
# 7) (Optional) Install Node.js
#-------------------------------------
install_node() {
  if command_exists node; then
    echo -e "${GREEN}Node.js is already installed: $(node --version)${NC}"
    return
  fi

  echo -e "${YELLOW}Node.js not found.${NC}"
  if confirm "Install Node via apt-get? (otherwise, we install via nvm)" "Y"; then
    sudo apt-get update -y
    sudo apt-get install -y nodejs npm
  else
    # Install NVM, then install Node
    if ! command_exists nvm; then
      echo -e "${GREEN}Installing NVM...${NC}"
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
      # shellcheck source=/dev/null
      source "$HOME/.nvm/nvm.sh"
    fi
    echo -e "${GREEN}Installing latest LTS Node via nvm...${NC}"
    nvm install --lts
    nvm use --lts
  fi
  echo -e "${GREEN}Node.js installation complete.${NC}"
}

#-------------------------------------
# 8) Use stow to symlink dotfiles
#-------------------------------------
symlink_dotfiles() {
  local dotfiles_dir
  dotfiles_dir="$( cd "$(dirname "$0")" && pwd )"  # script's directory

  # If your dotfiles are at this same repo root, we can do:
  # e.g. stow bash, oh-my-posh, bin, etc.
  echo -e "${GREEN}Symlinking dotfiles from: $dotfiles_dir${NC}"
  stow --verbose --restow --dir="$dotfiles_dir" --target="$HOME" bash bin oh-my-posh vim
  # If you have more directories: add them above (like 'aliases', 'functions' etc.),
  # or keep them inside 'bash' folder structure.
}

#-------------------------------------
# 9) Reload .bashrc
#-------------------------------------
reload_bashrc() {
  if [[ "$NONINTERACTIVE" == "true" ]]; then
    echo -e "${YELLOW}CI mode: not sourcing .bashrc automatically.${NC}"
    return
  fi

  echo -e "${GREEN}Reloading your new ~/.bashrc...${NC}"
  # shellcheck source=/dev/null
  source "$HOME/.bashrc"
}

#-------------------------------------
# MAIN
#-------------------------------------
main() {
  echo -e "${BOLD}=== Dotfiles Linux Bootstrap ===${NC}"

  # Possibly remove old files
  maybe_remove_old_dotfiles

  # Ensure stow
  install_stow

  # oh-my-posh
  install_oh_my_posh

  # Conda (optional)
  if confirm "Install Miniconda (conda)?" "Y"; then
    install_miniconda
  fi

  # Node (optional)
  if confirm "Install Node.js?" "Y"; then
    install_node
  fi

  # stow dotfiles
  symlink_dotfiles

  # reload .bashrc
  reload_bashrc

  echo -e "${GREEN}All done!${NC}"
}

main "$@"
