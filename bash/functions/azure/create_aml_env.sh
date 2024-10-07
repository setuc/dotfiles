# ~/functions/azure/create_aml_env.sh  
  
# Function to create an Azure Machine Learning environment  
create_aml_env() {  
    # ANSI color codes  
    RED='\033[0;31m'  
    GREEN='\033[0;32m'  
    YELLOW='\033[1;33m'  
    NC='\033[0m' # No Color  
  
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
  
    echo -e "${YELLOW}Creating conda environment...${NC}"  
    conda create -n "$env_name" python="$python_version" ipykernel notebook -y  
  
    if [ $? -ne 0 ]; then  
        echo -e "${RED}Failed to create conda environment. Exiting.${NC}"  
        return 1  
    fi  
  
    echo -e "${YELLOW}Activating environment...${NC}"  
    conda activate "$env_name"  
  
    if [ $? -ne 0 ]; then  
        echo -e "${RED}Failed to activate conda environment. Exiting.${NC}"  
        return 1  
    fi  
  
    echo -e "${YELLOW}Installing additional packages...${NC}"  
    conda install -y pip  
    pip install azureml-core  
  
    echo -e "${YELLOW}Installing IPython kernel...${NC}"  
    python -m ipykernel install --user --name "$env_name" --display-name "$display_name"  
  
    if [ $? -ne 0 ]; then  
        echo -e "${RED}Failed to install IPython kernel. Exiting.${NC}"  
        return 1  
    fi  
  
    echo -e "${GREEN}Environment '$env_name' created and activated with display name '$display_name'${NC}"  
    echo -e "${GREEN}Python version: $python_version${NC}"  
}  
