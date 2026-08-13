# Node version auto-switch via asdf.
#
# asdf's nodejs shims already resolve versions from the nearest .tool-versions
# by walking up the directory tree. This adds .nvmrc support on top: within a
# given directory .nvmrc wins over .tool-versions, because upstream repo
# maintainers tend to bump .nvmrc and forget .tool-versions. We walk up from
# $PWD and set ASDF_NODEJS_VERSION (which asdf's shims check before
# .tool-versions) as soon as we find a governing file; a bare .tool-versions
# with a nodejs entry stops the walk without setting an override, deferring
# to asdf's own resolution.
function __node_version_switch() {
  local dir="$PWD"

  while true; do
    if [[ -f "$dir/.nvmrc" ]]; then
      local version="$(<"$dir/.nvmrc")"
      version="${version//[[:space:]]/}"
      version="${version#v}"
      export ASDF_NODEJS_VERSION="$version"
      return
    fi
    if [[ -f "$dir/.tool-versions" ]] && grep -qE '^nodejs[[:space:]]' "$dir/.tool-versions"; then
      break
    fi
    [[ "$dir" == "/" ]] && break
    dir="${dir:h}"
  done

  unset ASDF_NODEJS_VERSION
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd __node_version_switch
__node_version_switch
