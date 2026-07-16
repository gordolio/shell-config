# Claude Code routed through CLIProxyAPI's Codex OAuth backend.

__tool_check_cmd "cliproxyapi" cliproxyapi claude
__tool_check_path "cliproxyapi-env" "$HOME/.config/op/cliproxyapi.env" secrets file

function __cliproxy_env_value
  set -l wanted $argv[1]
  set -l op_account $argv[2]
  set -l env_file "$HOME/.config/op/cliproxyapi.env"

  test -f "$env_file"; or return 1

  while read -l line
    set -l trimmed (string trim -- "$line")
    test -z "$trimmed"; and continue
    string match -q '#*' -- "$trimmed"; and continue

    set -l parts (string split -m1 '=' -- "$line")
    test (count $parts) -ge 2; or continue
    test "$parts[1]" = "$wanted"; or continue

    set -l value "$parts[2]"
    if string match -q 'op://*' -- "$value"
      type -q op; or return 1
      if test -n "$op_account"
        command op read --account "$op_account" "$value"
        return $status
      end
      command op read "$value"
      return $status
    end

    printf '%s' "$value"
    return 0
  end < "$env_file"

  return 1
end

function claudex
  set -l api_key
  set -l base_url
  set -l op_account
  set -l max_tool_use_concurrency 3
  set -l enable_tool_search false

  set -q CLIPROXY_OP_ACCOUNT; and set op_account $CLIPROXY_OP_ACCOUNT
  test -n "$op_account"; or set op_account (__cliproxy_env_value CLIPROXY_OP_ACCOUNT)
  set -q CLIPROXY_API_KEY; and set api_key $CLIPROXY_API_KEY
  set -q CLIPROXY_BASE_URL; and set base_url $CLIPROXY_BASE_URL
  test -n "$api_key"; or set api_key (__cliproxy_env_value CLIPROXY_API_KEY "$op_account")
  test -n "$base_url"; or set base_url (__cliproxy_env_value CLIPROXY_BASE_URL "$op_account")
  test -n "$base_url"; or set base_url http://127.0.0.1:8317
  set -q CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY; and set max_tool_use_concurrency $CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY
  set -q ENABLE_TOOL_SEARCH; and set enable_tool_search $ENABLE_TOOL_SEARCH

  if test -z "$api_key"
    echo "claudex: set CLIPROXY_API_KEY or add it to ~/.config/op/cliproxyapi.env" >&2
    return 1
  end

  env \
    -u ANTHROPIC_API_KEY \
    "ANTHROPIC_BASE_URL=$base_url" \
    "ANTHROPIC_AUTH_TOKEN=$api_key" \
    CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 \
    CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1 \
    "CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=$max_tool_use_concurrency" \
    "ENABLE_TOOL_SEARCH=$enable_tool_search" \
    claude $argv
end
