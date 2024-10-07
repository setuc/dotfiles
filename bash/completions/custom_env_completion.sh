# ~/bash/completions/custom_env_completion.sh  
  
# Custom environment completion  
_custom_env_completion() {  
    local cur=${COMP_WORDS[COMP_CWORD]}  
    local envs=()  
  
    # Add Conda environments  
    if command -v conda &> /dev/null; then  
        while IFS= read -r line; do  
            envs+=("$line")  
        done < <(conda env list | grep -v '^#' | awk '{print $1}')  
    fi  
  
    # Add virtualenv environments  
    if [ -d "$HOME/.virtualenvs" ]; then  
        while IFS= read -r line; do  
            envs+=("$line")  
        done < <(ls -1 "$HOME/.virtualenvs")  
    fi  
  
    COMPREPLY=($(compgen -W "${envs[*]}" -- "$cur"))  
}  
  
# Register custom completion for activate command  
complete -F _custom_env_completion activate  
