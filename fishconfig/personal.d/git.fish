# Git aliases and helpers

# Run git with the 1Password-provided npm/yarn auth tokens injected into the
# environment, so husky hooks (which run in a non-interactive shell that bypasses
# the npm/yarn function wrappers) can authenticate. We resolve the tokens with
# `op read` and pass them via `env` to the real git binary rather than wrapping in
# `op run`: op run proxies stdio to mask secrets, which strips the TTY and breaks
# commitizen / lint-staged's interactive prompts. A failed `op read` exports an
# empty value, which is harmless for hooks like `tsc` that don't need real auth.
function __git_with_npm_env
  if test -f "$HOME/.config/op/npm.env"; and type -q op
    set -l npm_env
    while read -l line
      test -z "$line"; and continue
      string match -q '#*' -- (string trim -- $line); and continue
      set -l parts (string split -m1 '=' -- $line)
      test (count $parts) -ge 2; or continue
      set -l val (command op read "$parts[2]")
      set -a npm_env "$parts[1]=$val"
    end < "$HOME/.config/op/npm.env"
    env $npm_env git $argv
  else
    command git $argv
  end
end

# git wrapper that adds clickable GitHub links to push/pull/remote update output.
# commit/push/ai also run husky hooks that may invoke yarn/npm (ai is the git-ai.ts
# alias, which spawns its own `git commit`), so route them through __git_with_npm_env
# to make the auth tokens available.
function git --wraps=git --description 'git with clickable GitHub links'
  if test (count $argv) -ge 2; and test "$argv[1]" = "remote"; and test "$argv[2]" = "update"
    command git $argv 2>&1 | $HOME/src/shell-config/bin/git-linkify
  else if test (count $argv) -ge 1; and test "$argv[1]" = "push"
    __git_with_npm_env $argv 2>&1 | $HOME/src/shell-config/bin/git-linkify
  else if test (count $argv) -ge 1; and test "$argv[1]" = "pull"
    command git $argv 2>&1 | $HOME/src/shell-config/bin/git-linkify
  else if test (count $argv) -ge 1; and begin test "$argv[1]" = "commit"; or test "$argv[1]" = "ai"; end
    __git_with_npm_env $argv
  else
    command git $argv
  end
end

function g --wraps=git --description 'alias g=git'
  git $argv
end

function gd --wraps='git diff' --description 'alias gd=git diff'
  git diff $argv
end

function gru --wraps='git remote update' --description 'alias gru=git remote update'
  git remote update $argv
end
