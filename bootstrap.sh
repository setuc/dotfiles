#!/usr/bin/env bash
#
# setup_linux_all_in_one.sh
# -------------------------
# Combines logic from your install.sh and setup_linux.sh into a single script,
# adds color-coded output, ensures oh-my-posh can be installed, can optionally
# install Miniconda & Node, plus stows dotfiles from the repo.
#
# Usage:
#   1) Place this script in your dotfiles repo root (which has software_list.json, bash/, oh-my-posh/, etc.)
#   2) chmod +x setup_linux_all_in_one.sh
#   3) ./setup_linux_all_in_one.sh
#
# It will:
#   - Prompt user to remove old dotfiles (if they want).
#   - Parse software_list.json and prompt for each software to install via apt or a custom method.
#   - Install oh-my-posh (needs 'unzip').
#   - Optionally install Miniconda (conda).
#   - Optionally install Node (via apt or nvm).
#   - Use stow to symlink your dotfiles.
#   - Source ~/.bashrc (unless CI=true).
#
# -------------------------------------------------

set -euo pipefail

#--------------#
# Color Codes  #
#--------------#
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

#--------------------------------------
# 0) Detect if running in CI for noninteractive
#--------------------------------------
CI_MODE="${CI:-false}"
if [[ "$CI_MODE" =~ ^(true|1)$ ]]; then
  echo -e "${YELLOW}Detected CI=true; script will run non-interactively.${NC}"
  NONINTERACTIVE="true"
else
  NONINTERACTIVE="false"
fi

#--------------------------------------
# 1) Helper functions
#--------------------------------------

command_exists() {
  command -v "$1" &>/dev/null
}

# A color-coded confirm function
confirm() {
  # Usage: confirm "message" [default=Y/N]
  local message="$1"
  local default="${2:-N}"

  if [[ "$NONINTERACTIVE" == "true" ]]; then
    # If in CI, auto-accept if default=Y
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

# This is the old "prompt_for_installation" from your setup_linux, but with color
prompt_for_installation() {
  # prompt_for_installation <software_name> <description> <default_bool>
  local name="$1"
  local desc="$2"
  local default_choice="$3"

  echo -e "${BOLD}${YELLOW}Install $name?${NC} ${desc}"
  local defchar="n"
  if [[ "$default_choice" == "true" ]]; then
    defchar="y"
  fi
  if confirm "Proceed?" "$defchar"; then
    return 0
  else
    return 1
  fi
}

# Install via apt if missing
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

#--------------------------------------
# 2) Possibly remove old dotfiles
#--------------------------------------
maybe_remove_old_dotfiles() {
  local -a files=(".bashrc" ".bash_aliases" ".bash_exports" ".bash_functions" ".bash_prompt")

  echo -e "${YELLOW}We will symlink your dotfiles into your home directory.${NC}"
  echo "If you have existing config files, they might conflict."

  if confirm "Remove existing ~/.bashrc, ~/.bash_aliases, etc.?" "N"; then
    for f in "${files[@]}"; do
      if [[ -f "$HOME/$f" || -L "$HOME/$f" ]]; then
        rm -f "$HOME/$f"
        echo -e "  Removed $HOME/$f"
      fi
    done
  else
    echo -e "${YELLOW}Skipping removal of old dotfiles.${NC}"
  fi
}

#--------------------------------------
# 3) Parse software_list.json and install
#--------------------------------------
install_from_software_list_json() {
  # This merges your old logic from setup_linux.sh
  local this_dir
  this_dir="$( cd "$(dirname "$0")" && pwd )"

  # Ensure we have 'jq'
  install_apt_pkg_if_needed "jq"

  if [[ ! -f "$this_dir/software_list.json" ]]; then
    echo -e "${RED}No software_list.json found in $this_dir; skipping that step.${NC}"
    return
  fi

  local software_list
  software_list="$(cat "$this_dir/software_list.json")"

  echo -e "${GREEN}Reading software_list.json and prompting for each...${NC}"

  sudo apt-get update -y

  # For each key in software_list
  # e.g. "git", "oh-my-posh", "python" ...
  # This code is basically your old setup:
  local packages
  packages=$(echo "$software_list" | jq -r 'keys[]')

  for software in $packages; do
    local description
    description=$(echo "$software_list" | jq -r ".[\"$software\"].description")
    local default_val
    default_val=$(echo "$software_list" | jq -r ".[\"$software\"].default")
    local apt_pkg
    apt_pkg=$(echo "$software_list" | jq -r ".[\"$software\"].apt")
    local custom_install
    custom_install=$(echo "$software_list" | jq -r ".[\"$software\"].custom_install // empty")

    if prompt_for_installation "$software" "$description" "$default_val"; then
      echo -e "${GREEN}Installing $software...${NC}"
      if [[ "$apt_pkg" != "custom" ]]; then
        # Normal apt install
        sudo apt-get install -y "$apt_pkg"
      else
        # custom install logic
        if [[ -n "$custom_install" && "$custom_install" != "null" ]]; then
          echo -e "${YELLOW}Running custom install for $software...${NC}"
          eval "$custom_install"
        else
          echo -e "${RED}No recognized install method for $software!${NC}"
        fi
      fi
    else
      echo -e "${YELLOW}Skipping $software...${NC}"
    fi
  done
}

#--------------------------------------
# 4) Install oh-my-posh (with unzip)
#--------------------------------------
install_oh_my_posh() {
  # Ensure unzip is installed (since oh-my-posh needs it)
  install_apt_pkg_if_needed "unzip"

  if command_exists oh-my-posh; then
    echo -e "${GREEN}oh-my-posh is already installed.${NC}"
    return
  fi

  echo -e "${GREEN}Installing oh-my-posh...${NC}"
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/bin"

  # Ensure ~/bin is on PATH, e.g. in ~/.bash_exports
  if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bash_exports" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bash_exports"
  fi
}

#--------------------------------------
# 5) (Optional) Install Miniconda
#--------------------------------------
install_miniconda() {
  if command_exists conda; then
    echo -e "${GREEN}conda (Miniconda/Anaconda) is already installed.${NC}"
    return
  fi

  echo -e "${GREEN}Installing Miniconda...${NC}"
  local MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
  local installer="miniconda.sh"

  wget -qO "$installer" "$MINICONDA_URL"
  bash "$installer" -b -p "$HOME/miniconda3"
  rm -f "$installer"

  # Initialize conda in .bashrc
  "$HOME/miniconda3/bin/conda" init bash
  echo -e "${GREEN}Miniconda installed. Please reload your shell or source ~/.bashrc to use conda.${NC}"
}

#--------------------------------------
# 6) (Optional) Install Node.js
#--------------------------------------
install_node() {
  if command_exists node; then
    echo -e "${GREEN}Node.js is already installed ($(node --version)).${NC}"
    return
  fi

  echo -e "${GREEN}Node.js not found on this system.${NC}"
  if confirm "Install Node via apt-get? (otherwise, we install via nvm)" "Y"; then
    sudo apt-get update -y
    sudo apt-get install -y nodejs npm
  else
    # Install NVM, then Node
    if ! command_exists nvm; then
      echo -e "${GREEN}Installing NVM...${NC}"
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
      # shellcheck source=/dev/null
      source "$HOME/.nvm/nvm.sh"
    fi
    echo -e "${GREEN}Installing Node (latest LTS) via nvm...${NC}"
    nvm install --lts
    nvm use --lts
  fi
  echo -e "${GREEN}Node.js installation done.${NC}"
}

#--------------------------------------
# 7) Stow your dotfiles
#--------------------------------------
stow_dotfiles() {
  # Integrate from install.sh
  echo -e "${GREEN}Using stow to symlink dotfiles...${NC}"
  local dotfiles_dir
  dotfiles_dir="$( cd "$(dirname "$0")" && pwd )"

  stow --verbose --restow --dir="$dotfiles_dir" --target="$HOME" bash bin oh-my-posh vim
  # Add any other directories you want to stow, e.g.:
  # stow --verbose --restow --dir="$dotfiles_dir" --target="$HOME" <something_else>
}

#--------------------------------------
# 8) Final step: source ~/.bashrc
#--------------------------------------
reload_bashrc() {
  if [[ "$NONINTERACTIVE" == "true" ]]; then
    echo -e "${YELLOW}CI mode: skipping direct sourcing of .bashrc.${NC}"
  else
    echo -e "${GREEN}Reloading ~/.bashrc now...${NC}"
    # shellcheck source=/dev/null
    source "$HOME/.bashrc"
  fi
}

#--------------------------------------
# MAIN
#--------------------------------------
main() {
  echo -e "${BOLD}=== Combined Linux Setup ===${NC}"

  # Possibly remove old dotfiles
  maybe_remove_old_dotfiles

  # Install from software_list.json
  install_from_software_list_json

  # oh-my-posh now that we have "unzip"
  install_oh_my_posh

  # (Optional) Miniconda
  if confirm "Install Miniconda (Conda)?" "Y"; then
    install_miniconda
  fi

  # (Optional) Node.js
  if confirm "Install Node.js?" "Y"; then
    install_node
  fi

  # Symlink dotfiles
  stow_dotfiles

  # If needed, ensure "~/.bash_aliases" is sourced in "~/.bashrc"
  # (like your old script)
  if ! grep -q "source ~/.bash_aliases" "$HOME/.bashrc"; then
    echo 'if [ -f ~/.bash_aliases ]; then source ~/.bash_aliases; fi' >> "$HOME/.bashrc"
  fi

  # Source ~/.bashrc
  reload_bashrc

  echo -e "${GREEN}All done!${NC}"
}

main "$@"
