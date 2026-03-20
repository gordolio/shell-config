# Git aliases and helpers

function __git_remote_update
  set -l github_base ""

  command git remote update $argv 2>&1 | while read -l line
    # Parse "From" lines to extract the GitHub base URL
    if string match -rq '^From (.+)$' -- $line
      set -l from_url (string match -r '^From (.+)$' -- $line)[2]
      set github_base ""
      # git@host:owner/repo.git
      if string match -rq '^[a-z]+@([^:]+):(.+)$' -- $from_url
        set -l parts (string match -r '^[a-z]+@([^:]+):(.+)$' -- $from_url)
        set github_base "https://$parts[2]/"(string replace -r '\.git$' '' -- $parts[3])
      # ssh://git@host/owner/repo or https://host/owner/repo
      else if string match -rq '^(https?|ssh)://([^@]+@)?([^/]+)/(.+)$' -- $from_url
        set -l parts (string match -r '^(https?|ssh)://([^@]+@)?([^/]+)/(.+)$' -- $from_url)
        set github_base "https://$parts[4]/"(string replace -r '\.git$' '' -- $parts[5])
      end
    end

    # Linkify "-> remote/branch" references with OSC 8 hyperlinks
    if test -n "$github_base"; and string match -rq -- '-> ([^/]+)/(.+)$' $line
      set -l parts (string match -r '-> ([^/]+)/(.+)$' -- $line)
      set -l ref "$parts[2]/$parts[3]"
      set -l branch "$parts[3]"
      set -l url "$github_base/compare/$branch"
      set -l hyperlink "\e]8;;"$url"\e\\\\"$ref"\e]8;;\e\\\\"
      string replace -- " $ref" " "(printf $hyperlink) $line
    else
      echo $line
    end
  end
end

function g --wraps=git --description 'alias g=git'
  git $argv
end

alias gd "git diff"
alias gru "git remote update"
