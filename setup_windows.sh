# Setup script for Windows environment using winget and JSON list

# Read the software list
$softwareList = Get-Content -Raw -Path "software_list.json" | ConvertFrom-Json

# Function to prompt user for installation
function Prompt-ForInstallation {
    param (
        [string]$name,
        [string]$description,
        [bool]$default
    )
    $choice = Read-Host "Install $name ($description)? (Y/n)"
    if ($choice -eq "" -and $default) { return $true }
    return $choice.ToLower() -eq 'y'
}

# Check if winget is available
if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "Winget is not installed. Please install it from the Microsoft Store or update your Windows."
    exit 1
}

# Install selected software
foreach ($software in $softwareList.PSObject.Properties) {
    $name = $software.Name
    $info = $software.Value
    if (Prompt-ForInstallation -name $name -description $info.description -default $info.default) {
        Write-Host "Installing $name..."
        winget install $info.winget
    }
}

# Install Stow (not available in winget, so we'll use pip)
if (Prompt-ForInstallation -name "Stow" -description "Symlink farm manager" -default $true) {
    pip install stow
}

# Clone dotfiles repository
if (!(Test-Path $HOME\.dotfiles)) {
    git clone https://github.com/setuc/dotfiles.git $HOME\.dotfiles
}

# Use stow to symlink configurations
Set-Location $HOME\.dotfiles
stow -v -R -t ~ powershell
stow -v -R -t ~ oh-my-posh

# Update PowerShell profile
$profileContent = @"
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
 
if (`$host.Name -eq 'ConsoleHost')
{
    Import-Module PSReadLine
}
Import-Module -Name Terminal-Icons
Import-Module PSReadLine
oh-my-posh init pwsh --config "`$env:POSH_THEMES_PATH\night-owl.omp.json" | Invoke-Expression
oh-my-posh init pwsh --config "`$HOME\.dotfiles\oh-my-posh\.poshthemes\jandedobbeleer.omp.json" | Invoke-Expression
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows
"@

$profileContent | Set-Content $PROFILE

# Install additional PowerShell modules
if (Prompt-ForInstallation -name "PSReadLine" -description "PowerShell module for enhanced command line editing" -default $true) {
    Install-Module -Name PSReadLine -Force
}
if (Prompt-ForInstallation -name "Terminal-Icons" -description "PowerShell module to show file and folder icons in the terminal" -default $true) {
    Install-Module -Name Terminal-Icons -Force
}

Write-Host "Windows setup complete!"