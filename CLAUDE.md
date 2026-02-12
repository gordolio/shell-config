# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a cross-platform shell configuration repository supporting Fish, Zsh, Vim, and Git configurations. The primary target is macOS with compatibility for Linux and Cygwin environments.

## Architecture

### Shell Configurations
- **Fish Shell** (`fishconfig/`) - Fisher for plugins, Oh My Posh for prompt, `personal.d/` for custom configs
- **Zsh** (`zshconfig/`) - Zinit for plugins, Oh My Posh for prompt, `personal.d/` for custom configs
Both shells share the same modular architecture:
- **Plugin manager**: Fisher (Fish) / Zinit (Zsh) — lightweight, just installs plugins
- **Prompt**: Oh My Posh — shared YAML config in `oh-my-poshconfig/`, symlinked to `~/.config/oh-my-posh`
- **Personal configs**: `personal.d/*.zsh` / `personal.d/*.fish` — sorted load order (00- first, zz- last)
- **Functions**: `personal.d/functions/` — one function per file
- **Tool registry**: `personal.d/00-tools.{zsh,fish}` — tracks tools, PATH, symlinks; provides `ls-tools`

### Editor Configuration
- **Vim** (`vimconfig/`) - Vundle-managed Vim configuration with support for MacVim, Neovide, and VimR

### Version Control
- **Git** (`gitconfig/`) - Git configuration with custom aliases and Beyond Compare 3 integration

## Shell Feature Parity

**When adding a new shell feature (alias, function, PATH entry, tool integration), it must be added to both Fish and Zsh configs.** The two shells should stay in sync. Corresponding files:

| Feature | Fish | Zsh |
|---|---|---|
| Tool registry | `fishconfig/personal.d/00-tools.fish` | `zshconfig/personal.d/00-tools.zsh` |
| General config | `fishconfig/personal.d/general.fish` | `zshconfig/personal.d/general.zsh` |
| Homebrew | `fishconfig/personal.d/brew.fish` | `zshconfig/personal.d/brew.zsh` |
| Zoxide | `fishconfig/personal.d/zoxide.fish` | `zshconfig/personal.d/zoxide.zsh` |
| JS runner | `fishconfig/personal.d/js-run.fish` | `zshconfig/personal.d/js-run.zsh` |
| History/Atuin | `fishconfig/personal.d/zz-history.fish` | `zshconfig/personal.d/zz-history.zsh` |
| Functions | `fishconfig/personal.d/functions/*.fish` | `zshconfig/personal.d/functions/*.zsh` |
| Main entry | `fishconfig/config.fish` | `zshconfig/zshrc` |

## Installation Pattern

This repository uses symlink installation managed by `ls-tools --fix-links`:
- `.vim` → `vimconfig/`, `.vimrc` → `vimconfig/vimrc`
- `.zshrc` → `zshconfig/zshrc`
- `.config/fish` → `fishconfig/`
- `.gitconfig` → `gitconfig/gitconfig`
- `.config/oh-my-posh` → `oh-my-poshconfig/`
- `.config/atuin/config.toml` → `atuinconfig/config.toml`

## Key Features

### Plugin Management
- **Fish**: Fisher package manager (`fishconfig/fish_plugins`)
- **Zsh**: Zinit with turbo mode (`zshconfig/zshrc`)
- **Vim**: Vundle plugin manager with bundles in `vimconfig/bundle/`

### Development Tools Integration
- Language managers: nvm, rbenv, pyenv, SDKman
- Directory navigation: zoxide
- Fuzzy finding: fzf integration across shells
- History search: Atuin with fzf fallback
- Editor features: GitHub Copilot, multiple language support

### Cross-Platform Support
- Conditional logic for macOS (`/opt/homebrew`, `/usr/local/`)
- Linux compatibility
- Cygwin support (`bin/win.sh`)
- Tool preference chains (e.g., eza > GNU ls > BSD ls)

### Token Management
- `tokens/` directory for API keys and credentials
- Conditional loading (only if files exist)
- Excluded from version control patterns

## Gitignored Local Configs
- `zshconfig/personal.d/local.zsh` — work-specific Zsh config
- `fishconfig/personal.d/local.fish` — work-specific Fish config

## No Build System
This is a pure configuration repository with no build process, tests, or package management beyond shell plugin managers.
