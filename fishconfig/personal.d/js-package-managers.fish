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
set -g __op_npm_auth_cmds install i ci add update up upgrade upgrade-interactive dedupe import dlx create fetch publish

function __op_run_npm_env
  set -l package_manager $argv[1]
  set -e argv[1]

  # No env-file → nothing to inject; run unchanged.
  if not test -f "$HOME/.config/op/npm.env"
    command "$package_manager" $argv
    return
  end

  # The first non-flag argument is the subcommand (a bare `yarn` means install).
  set -l subcmd ""
  for arg in $argv
    string match -q -- '-*' $arg; and continue
    set subcmd $arg
    break
  end
  test -z "$subcmd"; and test "$package_manager" = yarn; and set subcmd install

  if contains -- $subcmd $__op_npm_auth_cmds; and type -q op
    command op run --env-file "$HOME/.config/op/npm.env" -- "$package_manager" $argv
  else
    # Inject blank values for the token names so ~/.npmrc's ${...} substitution
    # doesn't choke, then exec the real binary with the TTY preserved.
    set -l blank_env
    while read -l line
      set -l trimmed (string trim -- $line)
      test -z "$trimmed"; and continue
      string match -q '#*' -- $trimmed; and continue
      set -l parts (string split -m1 '=' -- $line)
      set -a blank_env "$parts[1]="
    end < "$HOME/.config/op/npm.env"
    env $blank_env "$package_manager" $argv
  end
end

function npm
  __op_run_npm_env npm $argv
end

function yarn
  __op_run_npm_env yarn $argv
end

function pnpm
  __op_run_npm_env pnpm $argv
end
