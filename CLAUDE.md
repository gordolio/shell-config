# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a cross-platform shell configuration repository supporting Fish, Zsh, Vim, and Git configurations. The primary target is macOS with compatibility for Linux and Cygwin environments.

## Architecture

### Shell Configurations
- **Fish Shell** (`fishconfig/`) - Primary shell configuration with Fisher package manager
- **Zsh** (`zshconfig/`) - Oh My Zsh configuration with Agnoster theme  
- **Oh My Zsh** (`oh-my-zsh/custom/`) - Custom Zsh configurations and themes

### Editor Configuration
- **Vim** (`vimconfig/`) - Vundle-managed Vim configuration with support for MacVim, Neovide, and VimR

### Version Control
- **Git** (`gitconfig/`) - Git configuration with custom aliases and Beyond Compare 3 integration

## Installation Pattern

This repository uses manual symlink installation:
- Vim: Checkout to `~/.vim/` and symlink `vimrc` → `~/.vimrc`, `gvimrc` → `~/.gvimrc`
- Other configs: Manual symlinking from repository to home directory

## Key Features

### Plugin Management
- **Fish**: Fisher package manager (`fishconfig/fish_plugins`)
- **Zsh**: Oh My Zsh framework
- **Vim**: Vundle plugin manager with bundles in `vimconfig/bundle/`

### Development Tools Integration
- Language managers: nvm, rbenv, pyenv, SDKman
- Directory navigation: z plugin for smart jumping
- Fuzzy finding: fzf integration across shells
- Editor features: GitHub Copilot, multiple language support

### Cross-Platform Support
- Conditional logic for macOS (`/opt/homebrew`, `/usr/local/`)
- Linux compatibility
- Cygwin support (`bin/win.sh`)
- Tool preference chains (e.g., eza > GNU ls > BSD ls)

## Configuration Structure

### Fish Shell (`fishconfig/`)
- `config.fish` - Main configuration
- `conf.d/` - Auto-loaded configuration fragments
- `functions/` - Custom Fish functions
- `completions/` - Auto-completion scripts

### Token Management
- `tokens/` directory for API keys and credentials
- Conditional loading (only if files exist)
- Excluded from version control patterns

## No Build System
This is a pure configuration repository with no build process, tests, or package management beyond shell plugin managers.