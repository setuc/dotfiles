# Dotfiles

This repository stores my personal configuration files and helper scripts. The environment is managed through a single Ansible playbook that works across Windows (via WSL) and Linux hosts. Running the playbook installs all tools, links dotfiles with [GNU Stow](https://www.gnu.org/software/stow/) and configures the shell consistently.

## Quick start

1. Install [Ansible](https://docs.ansible.com/):
   ```bash
   sudo apt update && sudo apt install -y ansible
   ```
   On Windows you can install Ansible inside the Windows Subsystem for Linux (recommended) or
   via `pip` in PowerShell.
2. Clone the repository and run the playbook:
   ```bash
   git clone https://github.com/setuc/dotfiles.git ~/.dotfiles
   cd ~/.dotfiles
   ansible-playbook -i localhost, -c local --ask-become-pass setup.yml
   ```
   The command should be executed as your normal user. Use `--ask-become-pass` if you do not have passwordless sudo.

   For a purely PowerShell workflow on Windows, run the `setup_windows.sh` script instead:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   ./setup_windows.sh
   ```
   This script uses winget and Stow to replicate the Ansible configuration, but the playbook is preferred.

### Dependencies

The playbook installs all Python packages from `requirements.txt` as well as `jq` and the Azure CLI. If you choose to run the scripts outside of Ansible, install them manually:

```bash
sudo apt-get install -y python3 python3-pip jq
pip install -r requirements.txt
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

`jq` and the Azure CLI are required by some helper scripts in the `bin/` directory.

### Git configuration

Set your global Git identity if it is not configured already:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Nerd Fonts

For proper icons in the terminal prompt install a Nerd Font. The playbook can install [getnf](https://github.com/getnf/getnf) which downloads fonts directly:

```bash
curl -fsSL https://raw.githubusercontent.com/getnf/getnf/main/install.sh | bash
~/.local/bin/getnf -i IosevkaTerm
```

You can browse other fonts at <https://www.nerdfonts.com/>.

## Repository layout

- `bash/` – Bash configuration files, aliases, functions and completions
- `bin/` – Helper scripts placed on the PATH
- `ansible/` and `setup.yml` – Main playbook and roles
- `terraform/` – Example Terraform configurations
- Legacy shell scripts (`install.sh`, `setup_linux.sh`, `setup_windows.sh`) are retained for reference only

## Additional notes

- A `.pre-commit-config.yaml` is included to run `black`, `ruff` and `shellcheck`. Install [pre‑commit](https://pre-commit.com/) and run `pre-commit install` to enable automatic checks.
- Oh My Posh is installed into `~/bin` and initialised from `.bashrc` using the theme in `oh-my-posh/themes/night-owl.omp.json`.
- The playbook ensures the `unzip` package is present before installing Oh My Posh.

The `wd` alias defaults to the Azure ML working directory but respects the `AML_CODE_DIR` environment variable so you can override it as needed.

---

Licensed under the Unlicense. See [LICENSE](LICENSE) for details.
