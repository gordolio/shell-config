# Homebrew configuration and aliases

# Homebrew GitHub API token
if [[ -f "$HOME/src/shell-config/tokens/github_token.txt" ]]; then
  export HOMEBREW_GITHUB_API_TOKEN=$(<"$HOME/src/shell-config/tokens/github_token.txt")
fi

# Brew aliases
alias b="brew"
alias bud="command brew update"

function bs { command brew search "$@"; }
function bi { command brew install "$@"; }

# Wrapper function for brew to suggest shorter aliases
function brew {
  local suggest_msg=""

  if [[ "$1" == "update" && $# -eq 1 ]]; then
    suggest_msg="'bud'"
  elif [[ "$1" == "upgrade" ]]; then
    if [[ " $* " == *" --greedy "* ]]; then
      suggest_msg="'bug --greedy' or 'bugi'"
    else
      suggest_msg="'bug' or 'bugi'"
    fi
  elif [[ "$1" == "search" ]]; then
    suggest_msg="'bs'"
  elif [[ "$1" == "install" ]]; then
    suggest_msg="'bi'"
  fi

  # Show suggestion before command runs
  if [[ -n "$suggest_msg" ]]; then
    print -P "%B%U%F{red}%K{white}Tip: You can use $suggest_msg instead%f%k%u%b"
  fi

  # Run the actual brew command
  command brew "$@"

  # Show suggestion after command completes
  if [[ -n "$suggest_msg" ]]; then
    print -P "%B%U%F{red}%K{white}Tip: You can use $suggest_msg instead%f%k%u%b"
  fi
}

# bug function
function bug { command brew upgrade "$@"; }

function bugi {
  local -a outdated_formulae outdated_casks menu

  outdated_formulae=("${(@f)$(brew outdated --formula 2>/dev/null)}")
  outdated_casks=("${(@f)$(brew outdated --cask 2>/dev/null)}")

  # Filter out empty entries
  outdated_formulae=(${outdated_formulae:#})
  outdated_casks=(${outdated_casks:#})

  local f c
  for f in "${outdated_formulae[@]}"; do
    [[ -n "$f" ]] && menu+=("F\t$f")
  done
  for c in "${outdated_casks[@]}"; do
    [[ -n "$c" ]] && menu+=("C\t$c")
  done

  if (( ${#menu[@]} == 0 )); then
    echo "No outdated formulae or casks."
    return 0
  fi

  local picked
  picked=$(printf "%s\n" "${menu[@]}" | fzf --multi \
    --header='Keys:
  SPACE toggle | CTRL-A all | CTRL-D none | CTRL-T invert
  Type to filter | ENTER run upgrades | ESC cancel' \
    --delimiter="\t" \
    --with-nth=2.. \
    --bind="space:toggle,ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all" \
    --pointer='>' \
    --marker='*' \
    --color='pointer:#00d7ff,marker:#ffd75f,hl:#00d7ff,hl+:#00d7ff,fg:#c0c0c0,bg:#1c1c1c,fg+:#ffffff,bg+:#262626,info:#ffd75f,prompt:#87ff87,header:#87afff' \
    --preview='brew info {2} 2>/dev/null || brew info --cask {2} 2>/dev/null' \
    --preview-window='up:12:wrap')

  [[ -n "$picked" ]] || return 0

  local -a formulas casks
  local line tag name

  while IFS= read -r line; do
    tag="${line%%	*}"
    name="${line#*	}"
    if [[ "$tag" == "F" ]]; then
      formulas+=("$name")
    elif [[ "$tag" == "C" ]]; then
      casks+=("$name")
    fi
  done <<< "$picked"

  local formula_status=0 cask_status=0

  if (( ${#formulas[@]} > 0 )); then
    command brew upgrade "${formulas[@]}"
    formula_status=$?
  fi

  if (( ${#casks[@]} > 0 )); then
    command brew upgrade --cask "${casks[@]}"
    cask_status=$?
  fi

  (( formula_status == 0 && cask_status == 0 ))
}
