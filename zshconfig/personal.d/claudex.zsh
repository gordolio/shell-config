# Claude Code routed through CLIProxyAPI's Codex OAuth backend.

__tool_check_cmd "cliproxyapi" cliproxyapi claude
__tool_check_path "cliproxyapi-env" "$HOME/.config/op/cliproxyapi.env" secrets file

function __cliproxy_env_value {
  local wanted=$1
  local op_account=${2:-}
  local env_file="$HOME/.config/op/cliproxyapi.env"
  local key value

  [[ -f "$env_file" ]] || return 1

  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == '#'* || "$key" != "$wanted" ]] && continue

    if [[ "$value" == op://* ]]; then
      command -v op &>/dev/null || return 1
      if [[ -n "$op_account" ]]; then
        command op read --account "$op_account" "$value"
        return $?
      fi
      command op read "$value"
      return $?
    fi

    printf '%s' "$value"
    return 0
  done < "$env_file"

  return 1
}

function claudex {
  local api_key="${CLIPROXY_API_KEY:-}"
  local base_url="${CLIPROXY_BASE_URL:-}"
  local op_account="${CLIPROXY_OP_ACCOUNT:-}"

  [[ -n "$op_account" ]] || op_account=$(__cliproxy_env_value CLIPROXY_OP_ACCOUNT)
  [[ -n "$api_key" ]] || api_key=$(__cliproxy_env_value CLIPROXY_API_KEY "$op_account")
  [[ -n "$base_url" ]] || base_url=$(__cliproxy_env_value CLIPROXY_BASE_URL "$op_account")
  base_url="${base_url:-http://127.0.0.1:8317}"

  if [[ -z "$api_key" ]]; then
    echo "claudex: set CLIPROXY_API_KEY or add it to ~/.config/op/cliproxyapi.env" >&2
    return 1
  fi

  env \
    -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL="$base_url" \
    ANTHROPIC_AUTH_TOKEN="$api_key" \
    CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 \
    CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1 \
    CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY="${CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY:-3}" \
    ENABLE_TOOL_SEARCH="${ENABLE_TOOL_SEARCH:-false}" \
    claude "$@"
}
