# Codex CLI: statusline configuration + wrapper

__tool_check_cmd "codex" codex codex
__tool_check_path "codex-statusline" "$HOME/src/shell-config/codex/statusline.config.toml" codex file

function codex {
  # `--profile` only applies to codex's runtime subcommands (and the bare TUI);
  # management commands like `codex update`/`login` reject it. Only layer the
  # statusline profile when the subcommand actually accepts it.
  local sub="$1"
  if [[ -e "$HOME/.codex/statusline.config.toml" ]] \
    && [[ -z "$sub" || "$sub" == -* || "$sub" == (exec|review|resume|archive|unarchive|fork|mcp|sandbox|debug) ]]; then
    command codex --profile statusline "$@"
  else
    command codex "$@"
  fi
}
