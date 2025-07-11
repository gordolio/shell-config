function ghce --description "Wrapper around `gh copilot explain` to explain a given input command in natural language."
    set -l GH_DEBUG "$GH_DEBUG"
    set -l __USAGE "
Wrapper around `gh copilot explain` to explain a given input command in natural language.

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

    argparse -n ghce 'd/debug' 'h/help' -- $argv

    if set -q _flag_debug
        set GH_DEBUG "api"
    end

    if set -q _flag_help
        echo "$__USAGE"
        return 0
    end

    env GH_DEBUG="$GH_DEBUG" gh copilot explain $argv
end
