# git wrapper that adds clickable GitHub branch links to `git remote update`
function git {
  if [[ "$1" == "remote" && "$2" == "update" ]]; then
    __git_remote_update "${@:3}"
  else
    command git "$@"
  fi
}

function __git_remote_update {
  local github_base=""

  command git remote update "$@" 2>&1 | while IFS= read -r line; do
    # Parse "From" lines to extract the GitHub base URL
    if [[ "$line" =~ ^From\ (.+)$ ]]; then
      local from_url="${match[1]}"
      github_base=""
      # git@host:owner/repo.git
      if [[ "$from_url" =~ ^[a-z]+@([^:]+):(.+)$ ]]; then
        github_base="https://${match[1]}/${match[2]%.git}"
      # ssh://git@host/owner/repo or https://host/owner/repo
      elif [[ "$from_url" =~ ^(https?|ssh)://([^@]+@)?([^/]+)/(.+)$ ]]; then
        github_base="https://${match[3]}/${match[4]%.git}"
      fi
    fi

    # Linkify "-> remote/branch" references with OSC 8 hyperlinks
    if [[ -n "$github_base" && "$line" =~ '-> ([^/]+)/(.+)$' ]]; then
      local ref="${match[1]}/${match[2]}"
      local branch="${match[2]}"
      local url="$github_base/compare/$branch"
      local hyperlink=$'\e]8;;'"$url"$'\e\\'"$ref"$'\e]8;;\e\\'
      echo "${line/ $ref/ $hyperlink}"
    else
      echo "$line"
    fi
  done
}

alias g="git"
alias gs="git status"
alias gd="git diff"
alias gits="git"
alias gru="git remote update"
