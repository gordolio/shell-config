# Wrapper around `gh copilot explain`
function ghce {
  local GH_DEBUG="$GH_DEBUG"
  local __USAGE="
Wrapper around \`gh copilot explain\` to explain a given input command in natural language.

USAGE
    ghce [flags] <command>

FLAGS
    -d, --debug Enable debugging
    -h, --help  Display help usage

EXAMPLES
    # View disk usage, sorted by size
    \$ ghce 'du -sh | sort -h'

    # View git repository history as text graphical representation
    \$ ghce 'git log --oneline --graph --decorate --all'

    # Remove binary objects larger than 50 megabytes from git history
    \$ ghce 'bfg --strip-blobs-bigger-than 50M'
"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--debug) GH_DEBUG="api"; shift ;;
      -h|--help) echo "$__USAGE"; return 0 ;;
      *) break ;;
    esac
  done

  GH_DEBUG="$GH_DEBUG" gh copilot explain "$@"
}
