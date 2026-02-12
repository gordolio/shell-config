# Wrapper around `gh copilot suggest`
function ghcs {
  local TARGET="shell"
  local GH_DEBUG="$GH_DEBUG"
  local __USAGE="
Wrapper around \`gh copilot suggest\` to suggest a command based on a natural language description.

Supports executing suggested commands if applicable.

USAGE
    ghcs [flags] <prompt>

FLAGS
    -d, --debug         Enable debugging
    -h, --help          Display help usage
    -t, --target target Target for suggestion; must be shell, gh, git
                        default: \"shell\"

EXAMPLES
    - Guided experience
    \$ ghcs

    - Git use cases
    \$ ghcs -t git \"Undo the most recent local commits\"
    \$ ghcs -t git \"Clean up local branches\"
    \$ ghcs -t git \"Setup LFS for images\"

    - Working with the GitHub CLI in the terminal
    \$ ghcs -t gh \"Create pull request\"
    \$ ghcs -t gh \"List pull requests waiting for my review\"

    - General use cases
    \$ ghcs \"Kill processes holding onto deleted files\"
    \$ ghcs \"Convert SVG to PNG and resize\"
"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--debug) GH_DEBUG="api"; shift ;;
      -h|--help) echo "$__USAGE"; return 0 ;;
      -t|--target) TARGET="$2"; shift 2 ;;
      *) break ;;
    esac
  done

  local TMPFILE
  TMPFILE=$(mktemp -t gh-copilotXXX)
  trap 'rm -f "$TMPFILE"' EXIT

  if GH_DEBUG="$GH_DEBUG" gh copilot suggest -t "$TARGET" "$@" --shell-out "$TMPFILE"; then
    if [[ -s "$TMPFILE" ]]; then
      local FIXED_CMD
      FIXED_CMD=$(<"$TMPFILE")
      printf '%s\n' "$FIXED_CMD"
      eval "$FIXED_CMD"
    fi
  else
    return 1
  fi
}
