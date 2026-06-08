# JavaScript package managers (npm / yarn / pnpm) with 1Password-provided env.
#
# ~/.npmrc points the private @latermedia (GitHub Packages) and @fortawesome
# registries at `_authToken=${GH_AUTH_TOKEN}` / `${FA_AUTH_TOKEN}`. npm and yarn
# eagerly env-substitute those lines at startup and throw on an *undefined* var, so
# every command — even ones that never touch the registry — needs the token names
# to exist. Only commands that actually *fetch* (install, add, …) need the real
# values. So we resolve real tokens via 1Password for those, and inject blank
# placeholders for everything else.

__tool_check_cmd "op" op secrets
__tool_check_cmd "npm" npm package-managers
__tool_check_cmd "yarn" yarn package-managers
__tool_check_cmd "pnpm" pnpm package-managers

# Subcommands that fetch from the private registries and so need the *real* tokens.
# Everything else only needs the token names defined (empty is fine), which lets us
# run the real binary directly with the TTY intact — op run proxies stdio to mask
# secrets, which breaks interactive dev servers / watchers — and skips a 1Password
# round-trip on every run/dev/codegen.
__op_npm_auth_cmds=(
  install i ci add update up upgrade upgrade-interactive
  dedupe import dlx create fetch publish
)

function __op_run_npm_env {
  local package_manager=$1
  shift

  # No env-file → nothing to inject; run unchanged.
  if [[ ! -f "$HOME/.config/op/npm.env" ]]; then
    command "$package_manager" "$@"
    return
  fi

  # The first non-flag argument is the subcommand (a bare `yarn` means install).
  local subcmd="" arg
  for arg in "$@"; do
    [[ "$arg" == -* ]] && continue
    subcmd=$arg
    break
  done
  [[ -z "$subcmd" && "$package_manager" == "yarn" ]] && subcmd="install"

  local needs_auth=0 c
  for c in $__op_npm_auth_cmds; do
    [[ "$subcmd" == "$c" ]] && { needs_auth=1; break; }
  done

  if (( needs_auth )) && command -v op &>/dev/null; then
    command op run --env-file "$HOME/.config/op/npm.env" -- "$package_manager" "$@"
  else
    # Inject blank values for the token names so ~/.npmrc's ${...} substitution
    # doesn't choke, then exec the real binary with the TTY preserved.
    local -a blank_env
    local key _ref
    while IFS='=' read -r key _ref; do
      [[ -z "$key" || "$key" == '#'* ]] && continue
      blank_env+=("$key=")
    done < "$HOME/.config/op/npm.env"
    env "${blank_env[@]}" "$package_manager" "$@"
  fi
}

function npm {
  __op_run_npm_env npm "$@"
}

function yarn {
  __op_run_npm_env yarn "$@"
}

function pnpm {
  __op_run_npm_env pnpm "$@"
}
