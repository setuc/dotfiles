set background=dark
colorscheme solarized
let g:solarized_termtrans=1

set nocompatible          " Use Vim defaults instead of 100% vi compatibility

syntax on                 " Enable syntax highlighting

set ttyfast               " Faster redraw
set shortmess+=I          " No intro when starting Vim  
set autoindent            " Copy indent from current line when starting a new line
set smartindent           " Smart autoindenting when starting a new line
" Tab settings"
set smarttab              " Make tabbing smarter will realize you have 2 vs 4
set tabstop=4             " Number of spaces that a <Tab> in the file counts for
set expandtab             " Use spaces instead of tabs
set softtabstop=4         " Number of spaces that a <Tab> counts for 
set shiftwidth=4          " Number of spaces to use for each step of (auto)indent

set backspace=indent,eol,start  " Allow backspacing over everything in insert mode
set incsearch             " Show search matches as you type
set hlsearch              " Highlight search results
set cursorline            " Highlight the current 
set number                " Show the line number
set relativenumber
set updatetime=1000
set ignorecase            " Search insensitive
set smartcase             " ... but smart
set showbreak=↪
set showmatch             " Show matching brackets
set laststatus=2          " Always show the status line
set statusline=%F%m%r%h%w%=[%l,%v][%p%%]        " The status line at the bottom
set encoding=utf-8        " The encoding displayed.
set fileencoding=utf-8    " The encoding written to file.
set synmaxcol=300         " Don't try to highlight long lines

" Open all cmd args in new tabs
execute ":silent :tab all"