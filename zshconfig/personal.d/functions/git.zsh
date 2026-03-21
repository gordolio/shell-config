# git wrapper that adds clickable GitHub links to push/pull/remote update output
function git {
  if [[ "$1" == "remote" && "$2" == "update" ]]; then
    command git "$@" 2>&1 | "$HOME/src/shell-config/bin/git-linkify"
    return "${pipestatus[1]}"
  elif [[ "$1" == "push" || "$1" == "pull" ]]; then
    command git "$@" 2>&1 | "$HOME/src/shell-config/bin/git-linkify"
    return "${pipestatus[1]}"
  else
    command git "$@"
  fi
}

alias g="git"
alias gs="git status"
alias gd="git diff"
alias gits="git"
alias gru="git remote update"
