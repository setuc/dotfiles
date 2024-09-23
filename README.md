# dotfiles
@setuc dotfiles


### Linux Fresh Install
    git clone https://github.com/setuc/dotfiles.git .dotfiles
    cd .dotfiles
    chmod +x setup_linux.sh 
    ./setup_linux.sh 


    When working through the Azure ML VM, this is how the .bashrc file looked in the end. 
    oh my posh was installed in 
    cd HOME/cloudfiles/code/Users/setuchokshi/
    mkdir bin
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ./bin
    $HOME/cloudfiles/code/Users/setuchokshi/bin

## BashRC in azure.
    export PATH=$PATH:$HOME/cloudfiles/code/Users/setuchokshi/bin
    eval "$(oh-my-posh init bash --config $HOME/.dotfiles/oh-my-posh/.poshthemes/night-owl.omp.json)"
    if [ -f ~/.bash_aliases ]; then source ~/.bash_aliases; fi
    for file in $HOME/.bash_completion.d/*; do source $file; done

## Consider adding
git config --global user.name "Setuc"
git config --global user.email "setuc@noemail.com"

https://github.com/getnf/getnf?ref=linuxtldr.com

