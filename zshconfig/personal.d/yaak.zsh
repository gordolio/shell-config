# Yaak CLI, installed locally to avoid global npm/asdf churn.
export YAAK_CLI_HOME="${YAAK_CLI_HOME:-$HOME/.local/share/yaak-cli}"
export YAAK_DATA_DIR="${YAAK_DATA_DIR:-$HOME/src/Documents/Yaak}"
__tool_add_path "yaak-cli" "$YAAK_CLI_HOME/node_modules/.bin" path prepend

function yaak {
  if [[ -n "$YAAK_DATA_DIR" ]]; then
    command yaak --data-dir "$YAAK_DATA_DIR" "$@"
  else
    command yaak "$@"
  fi
}

alias yaak-install="$HOME/src/shell-config/bin/yaak-install"
alias yaak-update="$HOME/src/shell-config/bin/yaak-install"
