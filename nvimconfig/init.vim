" Neovim init — share config with Vim
" Add ~/.vim to runtimepath so Neovim finds plug.vim and plugins
" without needing a separate vim-plug install
set runtimepath^=~/.vim
set runtimepath+=~/.vim/after
source ~/.vimrc
