# Run git with the 1Password-provided npm/yarn auth tokens injected into the
# environment, so husky hooks (which run in a non-interactive shell that bypasses
# the npm/yarn function wrappers) can authenticate. We resolve the tokens with
# `op read` and pass them via `env` to the real git binary rather than wrapping in
# `op run`: op run proxies stdio to mask secrets, which strips the TTY and breaks
# commitizen / lint-staged's interactive prompts. A failed `op read` exports an
# empty value, which is harmless for hooks like `tsc` that don't need real auth.
function __git_with_npm_env {
  if [[ -f "$HOME/.config/op/npm.env" ]] && command -v op &>/dev/null; then
    local -a npm_env
    local key ref
    while IFS='=' read -r key ref; do
      [[ -z "$key" || "$key" == '#'* ]] && continue
      npm_env+=("$key=$(command op read "$ref")")
    done < "$HOME/.config/op/npm.env"
    env "${npm_env[@]}" git "$@"
  else
    command git "$@"
  fi
}

# git wrapper that adds clickable GitHub links to push/pull/remote update output.
# commit/push/ai also run husky hooks that may invoke yarn/npm (ai is the git-ai.ts
# alias, which spawns its own `git commit`), so route them through __git_with_npm_env
# to make the auth tokens available.
function git {
  if [[ "$1" == "remote" && "$2" == "update" ]]; then
    command git "$@" 2>&1 | "$HOME/src/shell-config/bin/git-linkify"
    return "${pipestatus[1]}"
  elif [[ "$1" == "push" ]]; then
    __git_with_npm_env "$@" 2>&1 | "$HOME/src/shell-config/bin/git-linkify"
    return "${pipestatus[1]}"
  elif [[ "$1" == "pull" ]]; then
    command git "$@" 2>&1 | "$HOME/src/shell-config/bin/git-linkify"
    return "${pipestatus[1]}"
  elif [[ "$1" == "commit" || "$1" == "ai" ]]; then
    __git_with_npm_env "$@"
  else
    command git "$@"
  fi
}

alias g="git"
alias gs="git status"
alias gd="git diff"
alias gits="git"
alias gru="git remote update"
