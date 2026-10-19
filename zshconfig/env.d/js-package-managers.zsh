# JavaScript package managers (npm / yarn / pnpm) with 1Password-provided env.
#
# ~/.npmrc (the default — loaded by every invocation everywhere: shells, IDE run
# configs, scripts) has NO auth lines for the private @latermedia (GitHub
# Packages) / @fortawesome registries. npm and yarn eagerly env-substitute any
# ${...} lines present at startup and throw on an *undefined* var (not on an
# empty one), so a naive setup needs GH_AUTH_TOKEN/FA_AUTH_TOKEN to exist just to
# run a dev server. Since the default config references neither var at all
# anymore, that failure mode is gone unconditionally — nothing (this wrapper, an
# IDE run config, whatever clears an env var) can trigger it, because there's
# nothing left to substitute.
#
# Only commands that actually *fetch* (install, add, …) need real auth. They get
# it by pointing npm/yarn at a second config file (~/.npmrcs/work-auth) that DOES
# have the substitution lines, via npm_config_userconfig, used only for that one
# call — combined with `op run` resolving the real tokens from 1Password for the
# same call, so the substitution always succeeds by construction. Everything
# else just execs the real binary with the TTY intact and no 1Password round-trip
# — op run proxies stdio to mask secrets, which breaks interactive dev
# servers/watchers.

__tool_check_cmd "op" op secrets
__tool_check_cmd "npm" npm package-managers
__tool_check_cmd "yarn" yarn package-managers
__tool_check_cmd "pnpm" pnpm package-managers

# Subcommands that fetch from the private registries and so need the *real* tokens.
__op_npm_auth_cmds=(
  install i ci add update up upgrade upgrade-interactive
  dedupe import dlx create fetch publish
)

# Config file carrying the real ${GH_AUTH_TOKEN}/${FA_AUTH_TOKEN} substitution.
# Never loaded by default — only the auth path below points npm/yarn at it.
__op_npm_auth_userconfig="$HOME/.npmrcs/work-auth"

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
    npm_config_userconfig="$__op_npm_auth_userconfig" command op run --env-file "$HOME/.config/op/npm.env" -- "$package_manager" "$@"
  else
    command "$package_manager" "$@"
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

# npx is deliberately not routed through __op_run_npm_env: it's not in the auth
# command list, so wrapping it would run `npx @latermedia/...` unauthenticated
# instead of resolving real tokens. It only needs the Prisma guard, which
# refuses `npx prisma` outright.
function npx {
  local db_guard="$HOME/src/shell-config/bin/prisma-target-guard.pl"
  if [[ -x "$db_guard" ]]; then
    "$db_guard" npx "$@" || return 1
  fi
  command npx "$@"
}
