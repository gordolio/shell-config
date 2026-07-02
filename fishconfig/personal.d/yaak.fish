# Yaak CLI, installed locally to avoid global npm/asdf churn.
if not set -q YAAK_CLI_HOME
  set -gx YAAK_CLI_HOME "$HOME/.local/share/yaak-cli"
end
if not set -q YAAK_DATA_DIR
  set -gx YAAK_DATA_DIR "$HOME/Library/Application Support/app.yaak.desktop"
end
__tool_add_path "yaak-cli" "$YAAK_CLI_HOME/node_modules/.bin" path prepend

function yaak
  if set -q YAAK_DATA_DIR
    command yaak --data-dir "$YAAK_DATA_DIR" $argv
  else
    command yaak $argv
  end
end

alias yaak-install "$HOME/src/shell-config/bin/yaak-install"
alias yaak-update "$HOME/src/shell-config/bin/yaak-install"
