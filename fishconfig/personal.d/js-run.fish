################################################################################
# js-install - Runs yarn or npm install by detecting the lock file type
function js-install
    if test -f "./package-lock.json"; and test -f "./yarn.lock"
        echo "❌ Both npm and yarn detected, preferring yarn"
        yarn install
    else if test -f "./yarn.lock"
        yarn install
    else if test -f "./package-lock.json"
        npm install
    end
end

alias ji "js-install"

################################################################################
# js-run - Runs package.json scripts and detects yarn or npm
# Look for `.git` in folder before looking for lockfile.
# Traverse up the directory tree until a `.git` is found and then look for lockfile.
function js-run
    set -l current_dir $PWD
    set -l git_root ""

    # Traverse up until we find .git directory or reach a state where current_dir becomes empty
    # (which happens if we process root "/" or a path like "/foo" and then try to get parent)
    while test "$current_dir" != ""; and not test -d "$current_dir/.git"
        set current_dir (string replace -r '/[^/]*$' '' "$current_dir")
    end

    # If the loop terminated, current_dir is either the directory containing .git,
    # or an empty string if .git was not found traversing upwards.
    # The bash equivalent `[[ -d "$current_dir/.git" ]]` would check `/.git` if current_dir is empty.
    # Fish's `test -d "$current_dir/.git"` behaves similarly when current_dir is empty.
    if test -d "$current_dir/.git"
        set git_root "$current_dir"
    else
        # If no .git directory found along the path, or if current_dir became empty (e.g., from root)
        set git_root $PWD
    end

    # Check for lockfiles in the determined root directory
    if test -f "$git_root/package-lock.json"; and test -f "$git_root/yarn.lock"
        echo "❌ Both npm and yarn detected, preferring yarn"
        yarn $argv
    else if test -f "$git_root/yarn.lock"
        yarn $argv
    else if test -f "$git_root/package-lock.json"
        npm run $argv
    else if test -f "$git_root/pnpm-lock.yaml"
        pnpm run $argv
    else
        echo "No package manager lockfile found in repository root: $git_root"
        return 1
    end
end

alias j "js-run"

