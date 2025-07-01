function ghcs --description "Wrapper around `gh copilot suggest` to suggest a command based on a natural language description of the desired output effort."
    set -l TARGET "shell"
    set -l GH_DEBUG "$GH_DEBUG"
    set -l __USAGE "
Wrapper around `gh copilot suggest` to suggest a command based on a natural language description of the desired output effort.

Supports executing suggested commands if applicable.

USAGE
    ghcs [flags] <prompt>

FLAGS
    -d, --debug         Enable debugging
    -h, --help          Display help usage
    -t, --target target Target for suggestion; must be shell, gh, git
                        default: \"$TARGET\"

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
    \$ ghcs -t gh \"Summarize work I have done in issues and pull requests for promotion\"

    - General use cases
    \$ ghcs \"Kill processes holding onto deleted files\"
    \$ ghcs \"Test whether there are SSL/TLS issues with github.com\"
    \$ ghcs \"Convert SVG to PNG and resize\"
    \$ ghcs \"Convert MOV to animated PNG\"
"

    argparse -n ghcs 'd/debug' 'h/help' 't/target=' -- $argv

    if set -q _flag_debug
        set GH_DEBUG "api"
    end

    if set -q _flag_help
        echo "$__USAGE"
        return 0
    end

    if set -q _flag_target
        set TARGET "$_flag_target"
    end

    set -l TMPFILE (mktemp -t gh-copilotXXX)
    trap 'rm -f "$TMPFILE"' EXIT

    if env GH_DEBUG="$GH_DEBUG" gh copilot suggest -t "$TARGET" $argv --shell-out "$TMPFILE"
        if test -s "$TMPFILE"
            set -l FIXED_CMD (cat $TMPFILE)
            printf '%s\n' "$FIXED_CMD"
            eval "$FIXED_CMD"
        end
    else
        return 1
    end
end


