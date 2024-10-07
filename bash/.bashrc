# ~/.bashrc: executed by bash(1) for non-login shells.  
  
# If not running interactively, don't do anything  
case $- in  
    *i*) ;;  
      *) return;;  
esac  
  
# Include global definitions (adjusted for Ubuntu/WSL)  
if [ -f /etc/bash.bashrc ]; then  
    source /etc/bash.bashrc  
fi  
  
# History and Shell Options  
  
# Avoid duplicate entries and entries starting with spaces in history  
HISTCONTROL=ignoreboth  
  
# Append to the history file, don't overwrite it  
shopt -s histappend  
  
# Set history size  
HISTSIZE=10000
HISTFILESIZE=2000
  
# Check the window size after each command and update LINES and COLUMNS.  
shopt -s checkwinsize  
  
# Make 'less' more friendly for non-text input files  
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"  
  
# Set a fancy prompt (non-color, unless we know we "want" color)  
case "$TERM" in  
    xterm-color|*-256color) color_prompt=yes;;  
esac  
  
# Force color prompt if desired  
# force_color_prompt=yes  
  
if [ -n "$force_color_prompt" ]; then  
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then  
        color_prompt=yes  
    else  
        color_prompt=  
    fi  
fi  
  
# Set prompt (removed debian_chroot)  
if [ "$color_prompt" = yes ]; then  
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '  
else  
    PS1='\u@\h:\w\$ '  
fi  
unset color_prompt force_color_prompt  
  
# If this is an xterm, set the title to user@host:dir  
case "$TERM" in  
    xterm*|rxvt*)  
        PS1="\[\e]0;\u@\h: \w\a\]$PS1"  
        ;;  
    *)  
        ;;  
esac  
  
# Enable color support of ls and add handy aliases  
if [ -x /usr/bin/dircolors ]; then  
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"  
    alias ls='ls --color=auto'  
    # alias dir='dir --color=auto'  
    # alias vdir='vdir --color=auto'  
  
    alias grep='grep --color=auto'  
    alias fgrep='fgrep --color=auto'  
    alias egrep='egrep --color=auto'  
fi  
  
# Source Bash aliases  
if [ -f ~/.bash_aliases ]; then  
    source ~/.bash_aliases  
fi  
  
# Source Bash exports (environment variables)  
if [ -f ~/.bash_exports ]; then  
    source ~/.bash_exports  
fi  
  
# Source Bash functions  
if [ -f ~/.bash_functions ]; then  
    source ~/.bash_functions  
fi  
  
# Source Bash prompt customization  
if [ -f ~/.bash_prompt ]; then  
    source ~/.bash_prompt  
fi  
  
# Source Bash completions  
if [ -d ~/.bash_completion.d ]; then  
    for file in ~/.bash_completion.d/*; do  
        [ -r "$file" ] && source "$file"  
    done  
fi  
  
# Initialize programmable completion features  
if ! shopt -oq posix; then  
    if [ -f /usr/share/bash-completion/bash_completion ]; then  
        source /usr/share/bash-completion/bash_completion  
    elif [ -f /etc/bash_completion ]; then  
        source /etc/bash_completion  
    fi  
fi  
  
# Add local bin to PATH (ensure no duplicates)  
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"  
  
# Initialize Oh My Posh (if installed)  
if command -v oh-my-posh &> /dev/null; then  
    eval "$(oh-my-posh init bash --config $HOME/.poshthemes/night-owl.omp.json)"  
fi  
  
# Update prompt before each command
# ~/functions/prompt/update_prompt.sh  
PROMPT_COMMAND="update_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"  
  
# Additional environment-specific configurations  
if [ -f ~/.bash_env ]; then  
    source ~/.bash_env  
fi

# >>> conda initialize >>>  
# !! Contents within this block are managed by 'conda init' !!  
__conda_setup="$('/home/setuc/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"  
if [ $? -eq 0 ]; then  
    eval "$__conda_setup"  
else  
    if [ -f "/home/setuc/miniconda3/etc/profile.d/conda.sh" ]; then  
        . "/home/setuc/miniconda3/etc/profile.d/conda.sh"  
    else  
        export PATH="/home/setuc/miniconda3/bin:$PATH"  
    fi  
fi  
unset __conda_setup  
# <<< conda initialize <<< 