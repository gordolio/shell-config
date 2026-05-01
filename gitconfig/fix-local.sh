#!/usr/bin/env bash
# Generate/update ~/.gitconfig.local with paths that can't be portable in
# the main gitconfig (git doesn't expand ~ or $HOME for gpg.program, etc.).
# Idempotent — only touches the keys it manages, leaves everything else
# in the file untouched.

set -u

shell_config="${SHELL_CONFIG:-$HOME/src/shell-config}"
local_file="$HOME/.gitconfig.local"

[ -f "$local_file" ] || touch "$local_file"

git config --file "$local_file" gpg.program "$shell_config/tigconfig/gpg-clean-verify.sh"

echo "Updated $local_file:"
echo "  gpg.program = $shell_config/tigconfig/gpg-clean-verify.sh"
