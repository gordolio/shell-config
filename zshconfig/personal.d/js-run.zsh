# Smart JS package manager detection

# js-install - Runs yarn or npm install by detecting the lock file type
function js-install {
  if [[ -f "./package-lock.json" && -f "./yarn.lock" ]]; then
    echo "Both npm and yarn detected, preferring yarn"
    yarn install
  elif [[ -f "./yarn.lock" ]]; then
    yarn install
  elif [[ -f "./package-lock.json" ]]; then
    npm install
  fi
}

alias ji="js-install"

# js-run - Runs package.json scripts and detects yarn or npm
# Traverses up the directory tree to find the git root, then checks for lockfiles
function js-run {
  local current_dir="$PWD"
  local git_root=""

  # Traverse up until we find .git directory or run out of path
  while [[ -n "$current_dir" && ! -d "$current_dir/.git" ]]; do
    current_dir="${current_dir%/*}"
  done

  if [[ -d "$current_dir/.git" ]]; then
    git_root="$current_dir"
  else
    git_root="$PWD"
  fi

  # Check for lockfiles in the determined root directory
  if [[ -f "$git_root/package-lock.json" && -f "$git_root/yarn.lock" ]]; then
    echo "Both npm and yarn detected, preferring yarn"
    yarn "$@"
  elif [[ -f "$git_root/yarn.lock" ]]; then
    yarn "$@"
  elif [[ -f "$git_root/package-lock.json" ]]; then
    npm run "$@"
  elif [[ -f "$git_root/pnpm-lock.yaml" ]]; then
    pnpm run "$@"
  else
    echo "No package manager lockfile found in repository root: $git_root"
    return 1
  fi
}

alias j="js-run"
