#!/bin/bash  
  
set -e  # Exit immediately if a command exits with a non-zero status  
  
# Color codes for output  
RED='\033[0;31m'  
GREEN='\033[0;32m'  
YELLOW='\033[1;33m'  
BLUE='\033[0;34m'  
NC='\033[0m' # No Color  
  
# Function to prompt for yes/no with a default value  
confirm() {  
    local prompt="$1"  
    local default="${2:-Y}"  
    local choice  
    if [[ "$default" =~ ^[Yy]$ ]]; then  
        prompt="$prompt [Y/n]: "  
    else  
        prompt="$prompt [y/N]: "  
    fi  
    read -r -p "$prompt" choice  
    choice=${choice:-$default}  
    case "$choice" in  
        y|Y ) return 0 ;;  
        n|N ) return 1 ;;  
        * )  
            echo -e "${RED}Invalid input. Please enter y or n.${NC}"  
            confirm "$1" "$default"  
            ;;  
    esac  
}  
  
# Function to check if a resource exists  
resource_exists() {  
    local resource_type="$1"  
    local name="$2"  
    local group="$3"  
  
    case "$resource_type" in  
        "storage account")  
            az storage account show -n "$name" -g "$group" &>/dev/null && return 0 || return 1  
            ;;  
        "keyvault")  
            az keyvault show -n "$name" -g "$group" &>/dev/null && return 0 || return 1  
            ;;  
        "ml workspace")  
            az ml workspace show -n "$name" -g "$group" &>/dev/null && return 0 || return 1  
            ;;  
        "cognitiveservices account")  
            az cognitiveservices account show -n "$name" -g "$group" &>/dev/null && return 0 || return 1  
            ;;  
        "search service")  
            az search service show -n "$name" -g "$group" &>/dev/null && return 0 || return 1  
            ;;  
        "app insights")  
            az monitor app-insights component show --app "$name" -g "$group" &>/dev/null && return 0 || return 1  
            ;;  
        *)  
            echo -e "${RED}Unknown resource type: $resource_type${NC}"  
            return 1  
            ;;  
    esac  
}  
  
# Function to display a list of regions and let the user select  
select_region() {  
    echo -e "${BLUE}Select the region to deploy resources:${NC}"  
    declare -A regions  
    regions=(  
        ["East US"]="eastus"  
        ["East US 2"]="eastus2"  
        ["West US 3"]="westus3"  
        ["Sweden Central"]="swedencentral"  
        ["Southeast Asia"]="southeastasia"  
        ["UK South"]="uksouth"  
        ["Australia East"]="australiaeast"  
        ["North Europe"]="northeurope"  
        ["West Europe"]="westeurope"  
        ["Central US"]="centralus"  
        # Add more regions as needed  
    )  
  
    PS3="Enter the number corresponding to your choice: "  
    select region_display_name in "${!regions[@]}"; do  
        if [[ -n "${regions[$region_display_name]}" ]]; then  
            REGION="${regions[$region_display_name]}"  
            echo -e "${GREEN}You have selected: $region_display_name ($REGION)${NC}"  
            break  
        else  
            echo -e "${RED}Invalid selection. Please try again.${NC}"  
        fi  
    done  
}  

# Function to create resource group name  
create_resource_group_name() {  
    echo -e "${BLUE}Let's construct a resource group name.${NC}"  
    read -r -p "Enter the customer code (e.g., cli, int, exp) [Default: int]: " CUSTOMER_CODE  
    CUSTOMER_CODE=${CUSTOMER_CODE:-int}  
    read -r -p "Enter the project or purpose (use two descriptive words, e.g., search experiments): " PURPOSE_WORDS  
    while [[ -z "$PURPOSE_WORDS" ]]; do  
        echo -e "${RED}Purpose cannot be empty.${NC}"  
        read -r -p "Enter the project or purpose (use two descriptive words): " PURPOSE_WORDS  
    done  
    read -r -p "Enter an identifier (e.g., date, timestamp) [Default: $(date +%Y%m%d)]: " IDENTIFIER  
    IDENTIFIER=${IDENTIFIER:-$(date +%Y%m%d)}  
  
    # Construct the resource group name  
    RG_NAME="${CUSTOMER_CODE}-${PURPOSE_WORDS// /-}-${IDENTIFIER}"  
    # Sanitize the RG_NAME  
    RG_NAME=$(echo "$RG_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')  
  
    echo -e "${GREEN}Proposed resource group name: $RG_NAME${NC}"  
  
    # Confirm the resource group name  
    if confirm "Do you want to use this resource group name?" "Y"; then  
        echo -e "${GREEN}Resource group name set to: $RG_NAME${NC}"  
    else  
        read -r -p "Enter your preferred resource group name: " RG_NAME  
        RG_NAME=$(echo "$RG_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')  
        echo -e "${GREEN}Resource group name set to: $RG_NAME${NC}"  
    fi  
} 

# Function to create Azure Blob Storage account  
create_storage_account() {  
    local name="$1"  
    if resource_exists "storage account" "$name" "$RG_NAME"; then  
        echo -e "${YELLOW}Storage account $name already exists.${NC}"  
    else  
        echo -e "${BLUE}Creating storage account $name...${NC}"  
        az storage account create -g "$RG_NAME" -n "$name" --sku Standard_LRS --kind StorageV2 --location "$REGION" --tags "$TAGS" 
    fi  
}  
  
# Function to create Key Vault  
create_key_vault() {  
    local name="$1"  
    if resource_exists "keyvault" "$name" "$RG_NAME"; then  
        echo -e "${YELLOW}Key Vault $name already exists.${NC}"  
    else  
        echo -e "${BLUE}Creating Key Vault $name...${NC}"  
        az keyvault create -g "$RG_NAME" -n "$name" --location "$REGION" --sku standard --tags "$TAGS"  
    fi  
  
    # Set access policies  
    # Get UPN of the OWNER  
    OWNER_UPN=$(az ad user list --filter "startswith(userPrincipalName,'$OWNER')" --query "[0].userPrincipalName" -o tsv)  
    if [[ -z "$OWNER_UPN" ]]; then  
        echo -e "${RED}Unable to find User Principal Name (UPN) for $OWNER in Azure AD.${NC}"  
        echo -e "${RED}Access policies for Key Vault will not be set.${NC}"  
    else  
        echo -e "${BLUE}Setting permissions for ${OWNER_UPN}"
        # az keyvault set-policy -n "$name" --upn "$OWNER_UPN" --secret-permissions get list set delete --certificate-permissions get list --key-permissions get list  
    fi  
}  
  
# Function to create Application Insights  
create_app_insights() {  
    local name="$1"  
    if resource_exists "app insights" "$name" "$RG_NAME"; then  
        echo -e "${YELLOW}Application Insights $name already exists.${NC}"  
    else  
        echo -e "${BLUE}Creating Application Insights $name...${NC}"
        # Create Log Analytics workspace if it doesn't exist
        local workspace_name="${name}-workspace"
        az monitor log-analytics workspace create \
             --resource-group "$RG_NAME" \
             --workspace-name "$workspace_name" \
             --location "$REGION" \
             --tags "$TAGS"

        # Create Application Insights with Workspace mode
        az monitor app-insights component create \
            --app "$name" \
            --resource-group "$RG_NAME" \
            --location "$REGION" \
            --kind "web" \
            --application-type "web" \
            --workspace "$workspace_name" \
            --tags "$TAGS"
    fi
}  
  
# Function to create Azure Machine Learning Workspace
create_ml_workspace() {
    local name="$1"

    #Define Local variables
    local storage_id
    local keyvault_id
    local appinsights_id

    # Azure Machine Learning requires storage account, keyvault, and app insights
    create_storage_account "$STORAGE_NAME"
    create_key_vault "$KEYVAULT_NAME"
    create_app_insights "$APPINSIGHTS_NAME"

    # Azure Machine Learning Compute Defaults
    compute_name="E4DS-4C32G-1X1"
    compute_type="Standard_E4ds_v4"

    # Check if ML workspace exists
    if resource_exists "ml workspace" "$name" "$RG_NAME"; then
        echo -e "${YELLOW}Machine Learning workspace $name already exists.${NC}"
    else
        echo -e "${BLUE}Creating Machine Learning workspace $name...${NC}"
        # Get full ARM IDs
        storage_id=$(az storage account show --name "$STORAGE_NAME" --resource-group "$RG_NAME" --query id -o tsv)
        keyvault_id=$(az keyvault show --name "$KEYVAULT_NAME" --resource-group "$RG_NAME" --query id -o tsv)
        appinsights_id=$(az monitor app-insights component show --app "$APPINSIGHTS_NAME" --resource-group "$RG_NAME" --query id -o tsv)

        az ml workspace create \
            --resource-group "$RG_NAME" \
            --name "$name" \
            --location "$REGION" \
            --storage-account "$storage_id" \
            --key-vault "$keyvault_id" \
            --application-insights "$appinsights_id" \
            --tags "$TAGS"
    fi

    # Check if compute exists
    if az ml compute show --name "$compute_name" --resource-group "$RG_NAME" --workspace-name "$name" &>/dev/null; then
        echo -e "${YELLOW}Machine Learning Compute $compute_name already exists.${NC}"
    else
        echo -e "${BLUE}Creating Machine Learning Compute $compute_name of type $compute_type...${NC}"
        az ml compute create \
            --resource-group "$RG_NAME" \
            --workspace-name "$name" \
            --name "$compute_name" \
            --type ComputeInstance \
            --size "$compute_type"
    fi
}
  
# Function to create Cognitive Service (Language or Document Intelligence)  
create_cognitive_service() {  
    local name="$1"  
    local kind="$2"
    local sku="$3"
    if resource_exists "cognitiveservices account" "$name" "$RG_NAME"; then  
        echo -e "${YELLOW}Cognitive Service $name ($kind) already exists.${NC}"  
    else  
        echo -e "${BLUE}Creating Cognitive Service $name ($kind)...${NC}"  
        az cognitiveservices account create -g "$RG_NAME" -n "$name" --kind "$kind" --sku "$sku" --location "$REGION" --tags "$TAGS" --yes  
    fi  
}  

# Function to create OpenAI model deployments
create_openai_model_deployments() {
    local account_name="$1"
    shift
    local desired_models=("$@")  # All remaining arguments are treated as model names

    # Check if the Cognitive Services account exists
    if ! resource_exists "cognitiveservices account" "$account_name" "$RG_NAME"; then
        echo -e "${RED}Cognitive Service $account_name does not exist. Please create it first.${NC}"
        return 1
    fi

    # Get available models, their versions, and SKUs
    local available_models
    available_models=$(az cognitiveservices model list --location "$REGION" --query "[].{name:model.name, version:model.version, sku:model.skus[0].name}" -o tsv)

    # Loop through desired models and create deployments
    while IFS=$'\t' read -r model version sku; do
        # if [[ " ${desired_models[@]} " =~ " ${model} " ]]; then
        # shell check recommended fix
        if [[ " ${desired_models[*]} " == *" ${model} "* ]]; then  
            local deployment_name="${model//./-}-deployment"
            if az cognitiveservices account deployment show --name "$account_name" --resource-group "$RG_NAME" --deployment-name "$deployment_name" &>/dev/null; then
                echo -e "${YELLOW}Deployment $deployment_name for model $model already exists.${NC}"
            else
                echo -e "${BLUE}Creating deployment $deployment_name for model $model...${NC}"
                if az cognitiveservices account deployment create \
                    --resource-group "$RG_NAME" \
                    --name "$account_name" \
                    --deployment-name "$deployment_name" \
                    --model-name "$model" \
                    --model-version "$version" \
                    --model-format OpenAI \
                    --sku-name "$sku" \
                    --sku-capacity 1; then
                    echo -e "${GREEN}Successfully created deployment for $model with SKU $sku${NC}"
                else
                    echo -e "${RED}Failed to create deployment for $model with SKU $sku${NC}"
                fi
            fi
        fi
    done <<< "$available_models"
}

# Function to create Azure Search service  
create_search_service() {  
    local name="$1"  
    if resource_exists "search service" "$name" "$RG_NAME"; then  
        echo -e "${YELLOW}Azure Search Service $name already exists.${NC}"  
    else  
        echo -e "${BLUE}Creating Azure Search Service $name...${NC}"  
        az search service create -g "$RG_NAME" -n "$name" --sku Basic --location "$REGION" --tags "$TAGS"  
    fi  
}  
  
# Function to truncate resource names to a maximum length  
truncate_name() {  
    local name="$1"  
    local max_length="$2"  
    echo "${name:0:$max_length}"  
}  
  
# Start of the script  
echo -e "${GREEN}Starting Azure resource provisioning script...${NC}"  
  
# Get current user UPN  
CURRENT_USER_UPN=$(az account show --query user.name -o tsv)  
CURRENT_USER_ALIAS=$(echo "$CURRENT_USER_UPN" | cut -d '@' -f 1)  
echo "Current user UPN: $CURRENT_USER_ALIAS"  
  
# Prompt for region  
select_region  
  
# Prompt for resource group  
read -r -p "Enter the resource group name (leave blank to create a new one): " RG_NAME_INPUT  
if [[ -z "$RG_NAME_INPUT" ]]; then  
    # Create resource group name  
    create_resource_group_name  
else  
    RG_NAME="$RG_NAME_INPUT"  
    RG_NAME=$(echo "$RG_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')  
    echo -e "${GREEN}Resource group name set to: $RG_NAME${NC}"  
fi 
  
# Set default owner to current user  
read -r -p "Enter owner name [Default: $CURRENT_USER_ALIAS]: " OWNER  
OWNER=${OWNER:-$CURRENT_USER_ALIAS}  
  
# Validate OWNER input and check if user exists in Azure AD  
OWNER_UPN=$(az ad user list --filter "startswith(userPrincipalName,'$OWNER')" --query "[0].userPrincipalName" -o tsv)  
if [[ -z "$OWNER_UPN" ]]; then  
    echo -e "${YELLOW}User $OWNER not found in Azure AD.${NC}"  
    # Ask to enter a valid UPN  
    while [[ -z "$OWNER_UPN" ]]; do  
        read -r -p "Please enter a valid UPN for the owner: " OWNER  
        OWNER_UPN=$(az ad user list --filter "startswith(userPrincipalName,'$OWNER')" --query "[0].userPrincipalName" -o tsv)  
        if [[ -z "$OWNER_UPN" ]]; then  
            echo -e "${YELLOW}User $OWNER not found in Azure AD.${NC}"  
        fi  
    done  
fi  
  
# Now OWNER_UPN contains the valid UPN of the owner  
echo -e "${GREEN}Owner UPN verified: $OWNER_UPN${NC}"  
  
# Calculate default deleteAfter date (default to 30 days from today)  
DEFAULT_DELETE_AFTER=$(date -d "+30 days" +%Y-%m-%d 2>/dev/null || date -v+30d +%Y-%m-%d)  
read -r -p "Enter delete after date (YYYY-MM-DD) [Default: $DEFAULT_DELETE_AFTER]: " DELETE_AFTER  
DELETE_AFTER=${DELETE_AFTER:-$DEFAULT_DELETE_AFTER}  
  
read -r -p "Enter purpose: " PURPOSE  
  
# Prompt for isProduction tag with default value  
read -r -p "Is this a production environment? (yes/no) [Default: no]: " IS_PRODUCTION  
IS_PRODUCTION=${IS_PRODUCTION:-no}  
IS_PRODUCTION=$(echo "$IS_PRODUCTION" | tr '[:upper:]' '[:lower:]')  
  
# Construct Tags  
TAGS=()  
TAGS+=("owner=$OWNER_UPN")  
TAGS+=("deleteAfter=$DELETE_AFTER")  
TAGS+=("purpose=$PURPOSE")  
TAGS+=("isProduction=$IS_PRODUCTION")  

# Check if resource group exists, create if not  
RG_EXISTS=$(az group exists --name "$RG_NAME")  
if [[ "$RG_EXISTS" == "true" ]]; then  
    echo -e "${GREEN}Using existing resource group $RG_NAME.${NC}"  
    if confirm "Do you want to proceed with the existing resource group?" "Y"; then  
        echo -e "${GREEN}Proceeding with existing resource group $RG_NAME.${NC}"  
    else  
        echo -e "${YELLOW}Exiting script as per user request.${NC}"  
        exit 1  
    fi  
else  
    echo -e "${BLUE}Creating resource group $RG_NAME in $REGION...${NC}"  
    az group create --name "$RG_NAME" --location "$REGION" --tags "${TAGS[@]}"  
fi  

# Optional: Prompt for a naming prefix for resources  
read -r -p "Enter a naming prefix for resources [Default: $RG_NAME]: " NAME_PREFIX  
NAME_PREFIX=${NAME_PREFIX:-$RG_NAME}  
NAME_PREFIX=$(echo "$NAME_PREFIX" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')  
  
# Initialize variables for shared resources with proper truncation  
# Storage account names have a maximum length of 24 characters  
MAX_STORAGE_NAME_LENGTH=24  
STORAGE_NAME_BASE="${NAME_PREFIX}storage"  
STORAGE_NAME=$(truncate_name "$STORAGE_NAME_BASE" $MAX_STORAGE_NAME_LENGTH)  
  
# Key Vault names have a maximum length of 24 characters and must start with a letter  
MAX_KEYVAULT_NAME_LENGTH=24  
KEYVAULT_NAME_BASE="${NAME_PREFIX}kv"  
KEYVAULT_NAME=$(truncate_name "$KEYVAULT_NAME_BASE" $MAX_KEYVAULT_NAME_LENGTH)  
# Ensure Key Vault name starts with a letter  
if [[ ! $KEYVAULT_NAME =~ ^[a-zA-Z] ]]; then  
    KEYVAULT_NAME="k${KEYVAULT_NAME:1}"  
fi  
  
# Application Insights name (max length 260, but we can truncate for consistency)  
APPINSIGHTS_NAME="${NAME_PREFIX}ai"  
  
# Prompt for resources to create  
if confirm "Create Azure Machine Learning?" "Y"; then  
    AML_NAME="${NAME_PREFIX}aml"  
    create_ml_workspace "$AML_NAME"  
else  
    # Azure Blob Storage  
    if confirm "Create Azure Blob Storage?" "Y"; then  
        create_storage_account "$STORAGE_NAME"  
    fi  
  
    # Azure Key Vault  
    if confirm "Create Azure Key Vault?" "Y"; then  
        create_key_vault "$KEYVAULT_NAME"  
    fi  
  
    # Application Insights  
    if confirm "Create Application Insights?" "Y"; then  
        create_app_insights "$APPINSIGHTS_NAME"  
    fi  
fi  


# Azure OpenAI  
if confirm "Create Azure OpenAI?" "Y"; then  
    OPENAI_NAME="${NAME_PREFIX}openai"  
    create_cognitive_service "$OPENAI_NAME" "OpenAI" "S0"

    # List of models to deploy
    # TODO: Improve the selection of the SKU
    OPENAI_MODELS=("gpt-35-turbo" "text-embedding-ada-002" "gpt-4-32k" "o1-preview" "o1-mini" "text-embedding-3-large" "text-embedding-3-small")
    create_openai_model_deployments "$OPENAI_NAME" "${OPENAI_MODELS[@]}"
fi  
  
# Azure AI Search  
if confirm "Create Azure AI Search?" "Y"; then  
    SEARCH_NAME="${NAME_PREFIX}search"  
    create_search_service "$SEARCH_NAME"  
fi  
  
# Azure Language Service  
if confirm "Create Azure Language Service?" "Y"; then  
    LANGUAGE_NAME="${NAME_PREFIX}language"  
    create_cognitive_service "$LANGUAGE_NAME" "TextAnalytics" "S"
fi  
  
# Azure Document Intelligence (Form Recognizer)  
if confirm "Create Azure Document Intelligence?" "Y"; then  
    DOCINT_NAME="${NAME_PREFIX}docint"  
    create_cognitive_service "$DOCINT_NAME" "FormRecognizer"  "S0"
fi  
  
echo -e "${GREEN}Resource creation complete!${NC}"  