#!/bin/bash  
set -e  
set -u  
  
# Function to generate .env file  
generate_env_file() {  
    # Initialize dry run to false  
    dry_run=false  
  
    # Check for 'dry run' parameter  
    if [[ "${1:-}" == "dry run" ]]; then  
        dry_run=true  
        shift  
    fi  
  
    # Prompt for resource group if not provided  
    resource_group="${1:-}"  
    if [[ -z "$resource_group" ]]; then  
        read -r -p "Enter your Azure Resource Group name: " resource_group  
    fi  
  
    echo "Using Resource Group: $resource_group"  
  
    # Check if az CLI is installed  
    if ! command -v az &> /dev/null; then  
        echo "Azure CLI is not installed. Please install it before running this script."  
        return 1  
    fi  
  
    # Ensure Azure CLI is logged in  
    if ! az account show &> /dev/null; then  
        echo "You are not logged in to Azure CLI. Please log in."  
        az login  
    fi  
  
    # Function to get Azure Search service details  
    get_search_service_details() {  
        echo "Retrieving Azure Search service details..."  
  
        # Get list of search services in the resource group  
        mapfile -t search_services < <(az search service list -g "$resource_group" --query "[].name" -o tsv)  
  
        if [ "${#search_services[@]}" -gt 1 ]; then  
            echo "Multiple Azure Search services found. Please select one:"  
            select search_name in "${search_services[@]}"; do  
                [ -n "$search_name" ] && break  
            done  
        elif [ "${#search_services[@]}" -eq 1 ]; then  
            search_name="${search_services[0]}"  
            echo "Using Azure Search service: $search_name"  
        else  
            echo "No Azure Search service found in resource group '$resource_group'."  
            return 1  
        fi  
  
        search_endpoint="https://${search_name}.search.windows.net"  
        search_key=$(az search admin-key show --service-name "$search_name" -g "$resource_group" --query "primaryKey" -o tsv)  
    }  
  
    # Function to get Azure OpenAI service details  
    get_openai_service_details() {  
        echo "Retrieving Azure OpenAI service details..."  
  
        # Get list of OpenAI services  
        mapfile -t openai_services < <(az cognitiveservices account list -g "$resource_group" --query "[?kind=='OpenAI'].name" -o tsv)  
  
        if [ "${#openai_services[@]}" -gt 1 ]; then  
            echo "Multiple Azure OpenAI services found. Please select one:"  
            select openai_name in "${openai_services[@]}"; do  
                [ -n "$openai_name" ] && break  
            done  
        elif [ "${#openai_services[@]}" -eq 1 ]; then  
            openai_name="${openai_services[0]}"  
            echo "Using Azure OpenAI service: $openai_name"  
        else  
            echo "No Azure OpenAI service found in resource group '$resource_group'."  
            return 1  
        fi  
  
        openai_endpoint=$(az cognitiveservices account show -n "$openai_name" -g "$resource_group" --query "properties.endpoint" -o tsv)  
        openai_key=$(az cognitiveservices account keys list -n "$openai_name" -g "$resource_group" --query "key1" -o tsv)  
    }  
  
    # Function to get Azure Storage account details  
    get_storage_account_details() {  
        echo "Retrieving Azure Storage account details..."  
  
        # Get list of storage accounts  
        mapfile -t storage_accounts < <(az storage account list -g "$resource_group" --query "[].name" -o tsv)  
  
        if [ "${#storage_accounts[@]}" -gt 1 ]; then  
            echo "Multiple Azure Storage accounts found. Please select one:"  
            select storage_name in "${storage_accounts[@]}"; do  
                [ -n "$storage_name" ] && break  
            done  
        elif [ "${#storage_accounts[@]}" -eq 1 ]; then  
            storage_name="${storage_accounts[0]}"  
            echo "Using Azure Storage account: $storage_name"  
        else  
            echo "No Azure Storage account found in resource group '$resource_group'."  
            return 1  
        fi  
  
        blob_connection_string=$(az storage account show-connection-string -n "$storage_name" -g "$resource_group" --query "connectionString" -o tsv)  
        blob_account_url="https://${storage_name}.blob.core.windows.net"  
    }  
  
    # Call functions to retrieve service details  
    get_search_service_details || return 1  
    get_openai_service_details || return 1  
    get_storage_account_details || return 1  
  
    # Prompt user for additional information  
    read -r -p "Enter your Azure Search Index name: " search_index  
    read -r -p "Enter your Azure Search Datasource name: " search_datasource  
    read -r -p "Enter your Azure Search Skillset name: " search_skillset  
    read -r -p "Enter your Azure Search Indexer name: " search_indexer  
    read -r -p "Enter your Azure OpenAI Embedding Deployment ID: " azure_openai_embedding_deployment_id  
    read -r -p "Enter your Azure Blob Container name: " blob_container  
  
    # Validate required variables  
    required_vars=(  
        search_endpoint search_index search_datasource search_skillset search_indexer  
        openai_endpoint azure_openai_embedding_deployment_id blob_container  
        blob_connection_string blob_account_url search_key openai_key  
    )  
  
    for var in "${required_vars[@]}"; do  
        if [ -z "${!var:-}" ]; then  
            echo "Error: Variable '$var' is not set."  
            return 1  
        fi  
    done  
  
    if [ "$dry_run" = true ]; then  
        echo -e "\nDry run enabled. The following .env file would be created:"  
        cat << EOF  
AZURE_SEARCH_SERVICE_ENDPOINT=$search_endpoint  
AZURE_SEARCH_INDEX=$search_index  
AZURE_SEARCH_DATASOURCE=$search_datasource  
AZURE_SEARCH_SKILLSET=$search_skillset  
AZURE_SEARCH_INDEXER=$search_indexer  
AZURE_OPENAI_ENDPOINT=$openai_endpoint  
AZURE_OPENAI_EMBEDDING_DEPLOYMENT_ID=$azure_openai_embedding_deployment_id  
AZURE_BLOB_CONTAINER=$blob_container  
AZURE_BLOB_CONNECTION_STRING=$blob_connection_string  
AZURE_BLOB_ACCOUNT_URL=$blob_account_url  
AZURE_SEARCH_ADMIN_KEY=$search_key  
AZURE_OPENAI_KEY=$openai_key  
EOF  
    else  
        # Create .env file  
        cat << EOF > .env  
AZURE_SEARCH_SERVICE_ENDPOINT=$search_endpoint  
AZURE_SEARCH_INDEX=$search_index  
AZURE_SEARCH_DATASOURCE=$search_datasource  
AZURE_SEARCH_SKILLSET=$search_skillset  
AZURE_SEARCH_INDEXER=$search_indexer  
AZURE_OPENAI_ENDPOINT=$openai_endpoint  
AZURE_OPENAI_EMBEDDING_DEPLOYMENT_ID=$azure_openai_embedding_deployment_id  
AZURE_BLOB_CONTAINER=$blob_container  
AZURE_BLOB_CONNECTION_STRING=$blob_connection_string  
AZURE_BLOB_ACCOUNT_URL=$blob_account_url  
AZURE_SEARCH_ADMIN_KEY=$search_key  
AZURE_OPENAI_KEY=$openai_key  
EOF  
  
        # Secure the .env file  
        chmod 600 .env  
  
        # Add .env to .gitignore  
        if [ -e .gitignore ]; then  
            if ! grep -Fxq ".env" .gitignore; then  
                echo ".env" >> .gitignore  
            fi  
        else  
            echo ".env" > .gitignore  
        fi  
  
        echo ".env file created successfully."  
        echo "Sensitive data is stored in .env (permissions set to 600)."  
        echo "Ensure '.env' is added to your .gitignore to prevent accidental commits."  
    fi  
} # End of generate_env_file function  