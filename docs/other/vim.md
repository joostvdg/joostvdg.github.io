title: Configure Your Vim
description: How To Make Your Vim Awesome
hero: My Awesome Vim

# VIM

## Install Vundle

```bash
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
```

## Install plugins

```bash
vim ~/.vimrc
```

```bash
filetype off
filetype plugin indent on
syntax on

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'gmarik/Vundle.vim'
Plugin 'reedes/vim-thematic'
Plugin 'airblade/vim-gitgutter'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'itchyny/lightline.vim'
Plugin 'nathanaelkane/vim-indent-guides'
Plugin 'scrooloose/nerdtree'
Plugin 'editorconfig/editorconfig-vim'
Plugin 'mhinz/vim-signify'

call vundle#end()

filetype plugin indent on
```

Open VIM, and install the plugins:

```bash
:installPlugins
```