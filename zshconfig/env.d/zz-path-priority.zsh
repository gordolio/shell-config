# Runs last in env.d so these prepends win: asdf's shims must sit ahead of pyenv,
# bun, Homebrew's node, nvm, and the SDKMAN candidates.

# SDKMAN candidates (java, gradle, maven, ...): what sdkman-init.sh puts on PATH
# and in <CANDIDATE>_HOME, without loading SDKMAN. The `sdk` command itself loads
# on first use (zshrc, interactive only).
export SDKMAN_DIR="$HOME/.sdkman"
() {
  local current name
  for current in "$SDKMAN_DIR"/candidates/*/current(N); do
    name=${${current:h:t}:u}
    export "${name//-/_}_HOME=$current"
    __tool_add_path "sdkman-${current:h:t}" "$current/bin" path prepend
  done
}

# nvm's default node, where eager nvm.sh used to put it (behind asdf), without
# loading nvm (~400ms). Only numeric defaults ("24", "v20.14.0") are resolved.
() {
  local alias_file="$HOME/.nvm/alias/default"
  [[ -r "$alias_file" ]] || return 0
  local default=$(<"$alias_file")
  [[ "$default" == (v|)[0-9]* ]] || return 0
  local -a bins=("$HOME"/.nvm/versions/node/v${default#v}(|.*)/bin(Nn))
  (( ${#bins} )) && __tool_add_path "nvm-default-node" "${bins[-1]}" path prepend
}

# ASDF (0.16+ is a Go rewrite — no asdf.sh, just put shims on PATH)
__tool_add_path "asdf-shims" "$HOME/.asdf/shims" path prepend

# Google Cloud SDK
__tool_source "google-cloud-sdk" "/opt/homebrew/share/google-cloud-sdk/path.zsh.inc" integration

# Added by LM Studio CLI (lms)
__tool_add_path "lm-studio-bin" "$HOME/.cache/lm-studio/bin" path append
# End of LM Studio CLI section
