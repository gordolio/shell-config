# git wrapper that adds clickable GitHub links to push/pull/remote update output
function git {
  if [[ "$1" == "remote" && "$2" == "update" ]]; then
    __git_remote_update "${@:3}"
  elif [[ "$1" == "push" || "$1" == "pull" ]]; then
    command git "$@" 2>&1 | "$HOME/src/shell-config/bin/git-linkify"
    return "${pipestatus[1]}"
  else
    command git "$@"
  fi
}

function __git_url_to_github {
  local url="$1"
  # git@host:owner/repo.git
  if [[ "$url" =~ ^[a-z]+@([^:]+):(.+)$ ]]; then
    echo "https://${match[1]}/${match[2]%.git}"
  # ssh://git@host/owner/repo or https://host/owner/repo
  elif [[ "$url" =~ ^(https?|ssh)://([^/@]+@)?([^/]+)/(.+)$ ]]; then
    echo "https://${match[3]}/${match[4]%.git}"
  # Short SSH: host:owner/repo (From line format, no user@ prefix)
  elif [[ "$url" =~ ^([^/:]+):(.+)$ ]]; then
    echo "https://${match[1]}/${match[2]%.git}"
  fi
}

# Build an OSC 8 hyperlink with blue dotted underline
function __git_hyperlink {
  local url="$1" text="$2"
  printf '%s' $'\e]8;;'"$url"$'\e\\\e[34;4:4m'"$text"$'\e[0m\e]8;;\e\\'
}

function __git_remote_update {
  local remotes
  remotes=($(command git remote))

  local remote
  for remote in "${remotes[@]}"; do
    local github_base
    github_base="$(__git_url_to_github "$(command git remote get-url "$remote" 2>/dev/null)")"
    echo "Fetching $remote"
    local output
    output="$(command git fetch "$remote" "$@" 2>&1)"

    # Detect default branch from local ref (no network call)
    local default_branch
    default_branch="$(command git symbolic-ref "refs/remotes/$remote/HEAD" 2>/dev/null | sed "s|refs/remotes/$remote/||")"

    # Fetch open PRs for branch→URL lookup (one API call per remote)
    local pr_json="" repo_path=""
    if [[ -n "$github_base" ]] && command -v gh &>/dev/null; then
      repo_path="$(echo "$github_base" | sed 's|https://[^/]*/||')"
      pr_json="$(gh pr list --repo "$repo_path" --state open --json headRefName,url --limit 1000 2>/dev/null)"
    fi

    # Release list fetched lazily on first tag
    local release_json="" release_fetched=0

    local line
    while IFS= read -r line; do
      # Branch lines: "-> remote/branch"
      if [[ -n "$github_base" && "$line" =~ '-> ([^/]+)/([^ ]+)' ]]; then
        local ref="${match[1]}/${match[2]}"
        local branch="${match[2]}"

        # Determine URL: default branch → commits, PR → PR URL, otherwise → commits
        local url=""
        if [[ "$branch" == "$default_branch" ]]; then
          url="$github_base/commits/$branch/"
        elif [[ -n "$pr_json" ]]; then
          url="$(echo "$pr_json" | jq -r --arg b "$branch" '.[] | select(.headRefName == $b) | .url // empty' 2>/dev/null)"
        fi
        if [[ -z "$url" ]]; then
          url="$github_base/commits/$branch/"
        fi

        echo "${line/ $ref/ $(__git_hyperlink "$url" "$ref")}"

      # Tag lines: "[new tag]  tagname -> tagname"
      elif [[ -n "$github_base" && "$line" =~ '\[new tag\]' && "$line" =~ '-> ([^ ]+)' ]]; then
        local tag="${match[1]}"

        # Lazy-fetch release list on first tag
        if [[ $release_fetched -eq 0 && -n "$repo_path" ]]; then
          release_json="$(gh release list --repo "$repo_path" --json tagName --limit 1000 2>/dev/null)"
          release_fetched=1
        fi

        # Release tag → releases page, plain tag → commits
        local url=""
        if [[ -n "$release_json" ]]; then
          local is_release
          is_release="$(echo "$release_json" | jq -r --arg t "$tag" '.[] | select(.tagName == $t) | .tagName // empty' 2>/dev/null)"
          if [[ -n "$is_release" ]]; then
            url="$github_base/releases/tag/$tag"
          fi
        fi
        if [[ -z "$url" ]]; then
          url="$github_base/commits/$tag"
        fi

        echo "${line/-> $tag/-> $(__git_hyperlink "$url" "$tag")}"
      else
        [[ -n "$line" ]] && echo "$line"
      fi
    done <<< "$output"
  done
}

alias g="git"
alias gs="git status"
alias gd="git diff"
alias gits="git"
alias gru="git remote update"
