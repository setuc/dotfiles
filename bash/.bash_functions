# ~/.bash_functions  
  
# Source all functions in ~/functions/ and its subdirectories  
if [ -d ~/functions ]; then  
    shopt -s globstar nullglob  
    for file in ~/functions/**/*.sh; do  
        [ -r "$file" ] && source "$file"  
    done  
    shopt -u globstar  
fi  
