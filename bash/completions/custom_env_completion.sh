# ~/bash/completions/custom_env_completion.sh
# shellcheck shell=bash

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

# Register custom completion for virtualenv "activate" script
complete -F _custom_env_completion activate

# Autocomplete conda environments for `conda activate`
_conda_activate_completion() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ ${prev} == "activate" ]]; then
        COMPREPLY=( $(compgen -W "$(conda env list | grep -v '^#' | awk '{print $1}')" -- "$cur") )
    fi
    return 0
}
complete -F _conda_activate_completion conda
