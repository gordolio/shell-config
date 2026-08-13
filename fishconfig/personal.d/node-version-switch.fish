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
function __node_version_switch --on-variable PWD
    set -l dir $PWD

    while true
        if test -f "$dir/.nvmrc"
            set -l nvmrc_version (string trim < "$dir/.nvmrc")
            set nvmrc_version (string replace -r '^v' '' $nvmrc_version)
            set -gx ASDF_NODEJS_VERSION $nvmrc_version
            return
        end
        if test -f "$dir/.tool-versions"; and grep -qE '^nodejs[[:space:]]' "$dir/.tool-versions"
            break
        end
        if test "$dir" = "/"
            break
        end
        set dir (path dirname $dir)
    end

    set -e ASDF_NODEJS_VERSION
end

__node_version_switch
