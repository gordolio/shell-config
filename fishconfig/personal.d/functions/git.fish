# git wrapper that adds clickable GitHub branch links to `git remote update`
function git --wraps=git --description 'git with clickable remote update links'
  if test (count $argv) -ge 2; and test "$argv[1]" = "remote"; and test "$argv[2]" = "update"
    __git_remote_update $argv[3..]
  else
    command git $argv
  end
end
