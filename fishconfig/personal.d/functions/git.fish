# git wrapper that adds clickable GitHub links to push/pull/remote update output
function git --wraps=git --description 'git with clickable GitHub links'
  if test (count $argv) -ge 2; and test "$argv[1]" = "remote"; and test "$argv[2]" = "update"
    __git_remote_update $argv[3..]
  else if test (count $argv) -ge 1; and begin test "$argv[1]" = "push"; or test "$argv[1]" = "pull"; end
    command git $argv 2>&1 | $HOME/src/shell-config/bin/git-linkify
  else
    command git $argv
  end
end
