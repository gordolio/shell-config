# Git aliases and helpers

function __git_url_to_github -a url
  # git@host:owner/repo.git
  if string match -rq '^[a-z]+@([^:]+):(.+)$' -- $url
    set -l parts (string match -r '^[a-z]+@([^:]+):(.+)$' -- $url)
    echo "https://$parts[2]/"(string replace -r '\.git$' '' -- $parts[3])
  # ssh://git@host/owner/repo or https://host/owner/repo
  else if string match -rq '^(https?|ssh)://[^/]+/(.+)$' -- $url
    set -l parts (string match -r '^(https?|ssh)://[^/]+/(.+)$' -- $url)
    set -l host (string match -r '://([^/@]+@)?([^/]+)' -- $url)[3]
    echo "https://$host/"(string replace -r '\.git$' '' -- $parts[3])
  # Short SSH: host:owner/repo (From line format, no user@ prefix)
  else if string match -rq '^([^/:]+):(.+)$' -- $url
    set -l parts (string match -r '^([^/:]+):(.+)$' -- $url)
    echo "https://$parts[2]/"(string replace -r '\.git$' '' -- $parts[3])
  end
end

# Build an OSC 8 hyperlink with blue dotted underline
function __git_hyperlink -a url text
  set -l osc_open (printf "\x1b]8;;%s\x1b\\" "$url")
  set -l sgr_on (printf "\x1b[34;4:4m")
  set -l sgr_off (printf "\x1b[0m")
  set -l osc_close (printf "\x1b]8;;\x1b\\")
  echo -n "$osc_open$sgr_on$text$sgr_off$osc_close"
end

function __git_remote_update
  for remote in (command git remote)
    set -l github_base (__git_url_to_github (command git remote get-url $remote 2>/dev/null))
    printf "Fetching %s\n" $remote
    set -l output (command git fetch $remote 2>&1)

    # Detect default branch from local ref (no network call)
    set -l default_branch (command git symbolic-ref "refs/remotes/$remote/HEAD" 2>/dev/null | string replace "refs/remotes/$remote/" "")

    # Fetch open PRs for branch→URL lookup (one API call per remote)
    set -l pr_json ""
    set -l repo_path ""
    if test -n "$github_base"; and command -v gh >/dev/null
      set repo_path (string replace -r '^https://[^/]+/' '' -- $github_base)
      set pr_json (gh pr list --repo "$repo_path" --state open --json headRefName,url --limit 1000 2>/dev/null | string collect)
    end

    # Release list fetched lazily on first tag
    set -l release_json ""
    set -l release_fetched 0

    for line in $output
      # Branch lines: "-> remote/branch"
      if test -n "$github_base"; and string match -rq -- '^.+-> ([^/]+)/(\S+)' $line
        set -l parts (string match -r -- '-> ([^/]+)/(\S+)' $line)
        set -l ref "$parts[2]/$parts[3]"
        set -l branch "$parts[3]"

        # Determine URL: default branch → commits, PR → PR URL, otherwise → commits
        set -l url ""
        if test "$branch" = "$default_branch"
          set url "$github_base/commits/$branch/"
        else if test -n "$pr_json"
          set url (printf '%s' "$pr_json" | jq -r --arg b "$branch" '.[] | select(.headRefName == $b) | .url // empty' 2>/dev/null)
        end
        if test -z "$url"
          set url "$github_base/commits/$branch/"
        end

        string replace -- " $ref" " "(__git_hyperlink "$url" "$ref") $line

      # Tag lines: "[new tag]  tagname -> tagname"
      else if test -n "$github_base"; and string match -rq -- '^\s*\*\s+\[new tag\]\s+\S+\s+-> (\S+)' $line
        set -l tag (string match -r -- '-> (\S+)' $line)[2]

        # Lazy-fetch release list on first tag
        if test $release_fetched -eq 0; and test -n "$repo_path"
          set release_json (gh release list --repo "$repo_path" --json tagName --limit 1000 2>/dev/null | string collect)
          set release_fetched 1
        end

        # Release tag → releases page, plain tag → commits
        set -l url ""
        if test -n "$release_json"
          set -l is_release (printf '%s' "$release_json" | jq -r --arg t "$tag" '.[] | select(.tagName == $t) | .tagName // empty' 2>/dev/null)
          if test -n "$is_release"
            set url "$github_base/releases/tag/$tag"
          end
        end
        if test -z "$url"
          set url "$github_base/commits/$tag"
        end

        string replace -- "-> $tag" "-> "(__git_hyperlink "$url" "$tag") $line
      else
        echo $line
      end
    end
  end
end

function g --wraps=git --description 'alias g=git'
  git $argv
end

alias gd "git diff"
alias gru "git remote update"
