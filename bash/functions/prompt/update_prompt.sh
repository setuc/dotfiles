# ~/functions/prompt/update_prompt.sh  
  
# Function to update Oh My Posh prompt with environment info  
update_prompt() {  
    if [ -n "$CONDA_DEFAULT_ENV" ]; then  
        export POSH_PYTHON_ENV="conda:$CONDA_DEFAULT_ENV"  
    elif [ -n "$VIRTUAL_ENV" ]; then  
        export POSH_PYTHON_ENV="venv:$(basename $VIRTUAL_ENV)"  
    else  
        unset POSH_PYTHON_ENV  
    fi  
}  
