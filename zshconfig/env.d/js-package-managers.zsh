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

# Token names referenced by ~/.npmrc. Non-fetching commands only need these names
# defined; the real values are resolved from 1Password for auth commands below.
__op_npm_token_vars=(GH_AUTH_TOKEN FA_AUTH_TOKEN)

function __op_run_npm_env {
  local package_manager=$1
  shift

  # Refuse destructive Prisma commands aimed at a non-local database: the target comes
  # from the repo's .env rather than the command line, so a stale .env silently points
  # a migration at staging. See bin/prisma-target-guard.pl for the rules and the
  # PRISMA_GUARD_ALLOW_REMOTE override.
  local db_guard="$HOME/src/shell-config/bin/prisma-target-guard.pl"
  if [[ -x "$db_guard" ]]; then
    "$db_guard" "$package_manager" "$@" || return 1
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

  if (( needs_auth )) && [[ -f "$HOME/.config/op/npm.env" ]] && command -v op &>/dev/null; then
    command op run --env-file "$HOME/.config/op/npm.env" -- "$package_manager" "$@"
  else
    # Inject blank values for the token names so ~/.npmrc's ${...} substitution
    # doesn't choke, then exec the real binary with the TTY preserved.
    local -a runtime_env
    local key value
    for key in $__op_npm_token_vars; do
      runtime_env+=("$key=")
    done
    if [[ -f "$HOME/.config/op/npm.env" ]]; then
      while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" == '#'* ]] && continue
        if [[ "$value" == op://* ]]; then
          runtime_env+=("$key=")
        else
          runtime_env+=("$key=$value")
        fi
      done < "$HOME/.config/op/npm.env"
    fi
    env "${runtime_env[@]}" "$package_manager" "$@"
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

# npx is deliberately not routed through __op_run_npm_env: `prisma` is not in the auth
# command list, so it would get blank registry tokens and break `npx @latermedia/...`.
# It only needs the Prisma guard, which refuses `npx prisma` outright.
function npx {
  local db_guard="$HOME/src/shell-config/bin/prisma-target-guard.pl"
  if [[ -x "$db_guard" ]]; then
    "$db_guard" npx "$@" || return 1
  fi
  command npx "$@"
}
