# Homebrew configuration and aliases

# Homebrew GitHub API token
if [ -f $HOME/src/shell-config/tokens/github_token.txt ]
   set -x HOMEBREW_GITHUB_API_TOKEN (cat $HOME/src/shell-config/tokens/github_token.txt)
end

# Brew aliases
alias b "brew"
alias bud "command brew update"

function bs
  command brew search $argv
end

function bi
  command brew install $argv
end

# Wrapper function for brew to suggest shorter aliases
function brew
  set -l suggest_msg ""

  # Check for "brew update" and suggest "bud"
  if test "$argv[1]" = "update"; and test (count $argv) -eq 1
    set suggest_msg "'bud'"
  # Check for "brew upgrade" and suggest "bug" or "bugi"
  else if test "$argv[1]" = "upgrade"
    if contains -- --greedy $argv
      set suggest_msg "'bug --greedy' or 'bugi'"
    else
      set suggest_msg "'bug' or 'bugi'"
    end
  # Check for "brew search" and suggest "bs"
  else if test "$argv[1]" = "search"
    set suggest_msg "'bs'"
  # Check for "brew install" and suggest "bi"
  else if test "$argv[1]" = "install"
    set suggest_msg "'bi'"
  end

  # Run the actual brew command
  command brew $argv

  # Show suggestion after command completes
  if test -n "$suggest_msg"
    set_color --bold --italics --underline --background brwhite brred
    echo "Tip: You can use $suggest_msg instead"
    set_color normal
  end
end

# bug function
function bug
  command brew upgrade $argv
end

function bugi --description "Upgrade selected outdated formulae/casks with fzf"
  set -l outdated_formulae (brew outdated --formula | string split \n | string trim | string match -r '.+')
  set -l outdated_casks    (brew outdated --cask    | string split \n | string trim | string match -r '.+')

  set -l menu
  for f in $outdated_formulae
    set -a menu (string join \t F $f)
  end
  for c in $outdated_casks
    set -a menu (string join \t C $c)
  end

  test (count $menu) -gt 0; or begin
    echo "No outdated formulae or casks."
    return 0
  end

  set -l picked (printf "%s\n" $menu | fzf --multi \
    --header='Keys:
  SPACE toggle • CTRL-A all • CTRL-D none • CTRL-T invert
  Type to filter • ENTER run upgrades • ESC cancel' \
    --delimiter="\t" \
    --with-nth=2.. \
    --bind="space:toggle,ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all" \
    --pointer='▶' \
    --marker='✓' \
    --color='pointer:#00d7ff,marker:#ffd75f,hl:#00d7ff,hl+:#00d7ff,fg:#c0c0c0,bg:#1c1c1c,fg+:#ffffff,bg+:#262626,info:#ffd75f,prompt:#87ff87,header:#87afff' \
    --preview='brew info {2} 2>/dev/null; or brew info --cask {2} 2>/dev/null' \
    --preview-window='up:12:wrap')

  test -n "$picked"; or return 0

  set -l formulas
  set -l casks

  for line in (string split \n -- $picked)
    set -l parts (string split \t -- $line)
    set -l tag  $parts[1]
    set -l name $parts[2]

    if test "$tag" = "F"
      set -a formulas $name
    else if test "$tag" = "C"
      set -a casks $name
    end
  end

  set -l formula_status 0
  set -l cask_status 0

  if test (count $formulas) -gt 0
    command brew upgrade $formulas
    set formula_status $status
  end

  if test (count $casks) -gt 0
    command brew upgrade --cask $casks
    set cask_status $status
  end

  test $formula_status -eq 0 -a $cask_status -eq 0
end
