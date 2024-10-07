# ~/functions/conda/create_conda_env.sh  
  
# Function to create a Conda environment  
create_conda_env() {  
    if [ $# -lt 2 ]; then  
        echo "Usage: create_conda_env <env_name> <python_version> [packages/file]"  
        return 1  
    fi  
  
    env_name="$1"  
    python_version="$2"  
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
            conda install "$@" -y  
        fi  
    fi  
  
    echo "Environment '$env_name' created with Python $python_version"  
    conda list  
}  
