# Local/work-specific fish configuration
# This file is gitignored - safe for work-specific settings
#
# Later shared_utils integration
# See: https://github.com/Latermedia/shared_utils

# Set the shared_utils home directory
set -gx LATER_SHARED_UTILS_HOME $HOME/src/later/shared_utils

# Skip update checks by uncommenting:
# set -gx LATER_SHARED_SKIP_UPDATES true

# Cache file for function list
set -g __later_cache_file ~/.cache/fish/later_shared_utils_functions

# ============================================================================
# Auto-update check for shared_utils (runs in background)
# ============================================================================

function __later_check_updates_bg
    # Skip if disabled
    if test "$LATER_SHARED_SKIP_UPDATES" = "true"
        return 0
    end

    # Skip if not configured
    if not set -q LATER_SHARED_UTILS_HOME; or not test -d "$LATER_SHARED_UTILS_HOME"
        return 0
    end

    set -l git_dir "$LATER_SHARED_UTILS_HOME/.git"
    set -l stable_branch "main"

    # Check current branch
    set -l current_branch (git --git-dir=$git_dir --work-tree=$LATER_SHARED_UTILS_HOME branch --show-current 2>/dev/null)
    if test "$current_branch" != "$stable_branch"
        return 0
    end

    # Check for local changes
    set -l git_status (git --git-dir=$git_dir --work-tree=$LATER_SHARED_UTILS_HOME status -s 2>/dev/null)
    if test -n "$git_status"
        return 0
    end

    # Fetch and check for updates
    git --git-dir=$git_dir --work-tree=$LATER_SHARED_UTILS_HOME fetch origin $stable_branch --quiet 2>/dev/null
    set -l updates (git --git-dir=$git_dir --work-tree=$LATER_SHARED_UTILS_HOME log $stable_branch..origin/$stable_branch --oneline 2>/dev/null)

    if test -n "$updates"
        # Notify user - this will appear after their first command
        echo ""
        echo "Updates available for Later's shared_utils. Run 'later_update' to update."
    end
end

# Manual update command
function later_update
    if not set -q LATER_SHARED_UTILS_HOME; or not test -d "$LATER_SHARED_UTILS_HOME"
        echo "LATER_SHARED_UTILS_HOME not set or directory doesn't exist"
        return 1
    end

    set -l git_dir "$LATER_SHARED_UTILS_HOME/.git"

    echo "Updating shared_utils..."
    git --git-dir=$git_dir --work-tree=$LATER_SHARED_UTILS_HOME pull origin main

    echo "Refreshing function cache..."
    __later_refresh_cache

    echo "Reloading functions..."
    __later_load_from_cache

    echo "Done! New functions are now available."
end

# ============================================================================
# Cached function loading (fast synchronous startup)
# ============================================================================

function __later_refresh_cache
    # Ensure cache directory exists
    mkdir -p (dirname $__later_cache_file)

    # Get functions defined by shared_utils
    bash -c '
        baseline=$(declare -F | cut -d" " -f3)
        source "$LATER_SHARED_UTILS_HOME/dotfiles/kanto_main.sh" 2>/dev/null
        after=$(declare -F | cut -d" " -f3)
        comm -13 <(echo "$baseline" | sort) <(echo "$after" | sort)
    ' | grep -v '^_' > $__later_cache_file
end

function __later_load_from_cache
    # Skip if not configured
    if not set -q LATER_SHARED_UTILS_HOME; or not test -d "$LATER_SHARED_UTILS_HOME"
        return 0
    end

    # If cache doesn't exist, create it (first run)
    if not test -f $__later_cache_file
        __later_refresh_cache
    end

    # Load functions from cache (fast!)
    for func in (cat $__later_cache_file)
        eval "function $func
            bass \"source \\\$LATER_SHARED_UTILS_HOME/dotfiles/kanto_main.sh && $func \$argv\"
        end"
    end

    # Static aliases
    alias staging_console "kanto_command staging"
    alias prod_console "kanto_command production"
    alias local_release_pending "git fetch --all -q; git log --format=short origin/release..release"
end

# List all loaded functions
function later_list_functions
    echo "Functions loaded from shared_utils:"
    echo "===================================="
    if test -f $__later_cache_file
        cat $__later_cache_file
    else
        echo "(cache not found - run 'later_update' to refresh)"
    end
end

# Force cache refresh
function later_refresh
    echo "Refreshing function cache..."
    __later_refresh_cache
    echo "Reloading functions..."
    __later_load_from_cache
    echo "Done!"
end

# ============================================================================
# Initialize on shell start (interactive only)
# ============================================================================

if status --is-interactive
    # Fast synchronous load from cache
    __later_load_from_cache

    # Background: check for updates (won't block startup)
    fish -c "__later_check_updates_bg" &
    disown
end
