# Rust/cargo environment
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# Dioxus CLI. Homebrew's deno also ships a `dx`, and /opt/homebrew/bin is ahead
# of ~/.cargo/bin on PATH.
if [[ -x "$HOME/.cargo/bin/dx" ]]; then
  function dx {
    command "$HOME/.cargo/bin/dx" "$@"
  }
fi
