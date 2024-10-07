# ~/.bash_aliases  
  
# Source all alias files in ~/.aliases/  
if [ -d ~/.aliases ]; then  
    for file in ~/.aliases/*.aliases; do  
        [ -r "$file" ] && source "$file"  
    done  
fi