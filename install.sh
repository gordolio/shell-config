#!/bin/bash
set -euo pipefail

REPO_URL="https://github.com/gordolio/shell-config.git"
SHELL_CONFIG="$HOME/src/shell-config"

# --- helpers ---
info()  { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m  ✅ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m  ⚠️  %s\033[0m\n' "$*"; }
fail()  { printf '\033[1;31m  ❌ %s\033[0m\n' "$*"; }
abort() { fail "$*"; exit 1; }

# --- preflight ---
info "Checking for Homebrew..."
if ! command -v brew &>/dev/null; then
  abort "Homebrew is required but not installed. Install it first:
  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
fi
ok "Homebrew found"

# --- clone ---
info "Setting up shell-config..."
if [ -d "$SHELL_CONFIG" ]; then
  warn "$SHELL_CONFIG already exists, pulling latest"
  git -C "$SHELL_CONFIG" pull --ff-only || warn "Pull failed, continuing with existing checkout"
else
  mkdir -p "$HOME/src"
  git clone "$REPO_URL" "$SHELL_CONFIG"
  ok "Cloned to $SHELL_CONFIG"
fi

# --- symlinks ---
fix_symlink() {
  local link_path="$1" target="$2" name="$3"

  if [ -L "$link_path" ]; then
    rm "$link_path"
  elif [ -e "$link_path" ]; then
    mv "$link_path" "$link_path.backup"
    warn "Backed up existing $name to $link_path.backup"
  fi

  local parent_dir
  parent_dir=$(dirname "$link_path")
  [ -d "$parent_dir" ] || mkdir -p "$parent_dir"

  if ln -s "$target" "$link_path"; then
    ok "$name -> $target"
  else
    fail "Could not create symlink: $name"
    return 1
  fi
}

info "Creating symlinks..."
fix_symlink "$HOME/.vim"                        "$SHELL_CONFIG/vimconfig"              ".vim"
fix_symlink "$HOME/.vimrc"                      "$SHELL_CONFIG/vimconfig/vimrc"        ".vimrc"
fix_symlink "$HOME/.zshrc"                      "$SHELL_CONFIG/zshconfig/zshrc"        ".zshrc"
fix_symlink "$HOME/.gitconfig"                  "$SHELL_CONFIG/gitconfig/gitconfig"    ".gitconfig"
fix_symlink "$HOME/.config/fish"                "$SHELL_CONFIG/fishconfig"             ".config/fish"
fix_symlink "$HOME/.config/atuin/config.toml"   "$SHELL_CONFIG/atuinconfig/config.toml" ".config/atuin"
fix_symlink "$HOME/.config/oh-my-posh"          "$SHELL_CONFIG/oh-my-poshconfig"       ".config/oh-my-posh"

# --- pick shell and run ls-tools ---
info "Verifying setup..."
if command -v fish &>/dev/null; then
  ok "Fish detected — running ls-tools"
  fish -c "source $SHELL_CONFIG/fishconfig/personal.d/00-tools.fish; ls-tools"
elif command -v zsh &>/dev/null; then
  ok "Zsh detected (no fish) — running ls-tools"
  zsh -c "source $SHELL_CONFIG/zshconfig/personal.d/00-tools.zsh; ls-tools"
else
  warn "Neither fish nor zsh found — install one to use ls-tools"
fi

echo ""
info "Done! Open a new shell to start using your config."
if ! command -v fish &>/dev/null; then
  echo "  Tip: brew install fish"
fi
