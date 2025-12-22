function _nvm_install --on-event nvm_install
    set --query nvm_mirror || set --universal nvm_mirror https://nodejs.org/dist
    set --query XDG_DATA_HOME || set --local XDG_DATA_HOME ~/.local/share
    set --universal nvm_data $XDG_DATA_HOME/nvm

    test ! -d $nvm_data && command mkdir -p $nvm_data
    echo "Downloading the Node distribution index..." 2>/dev/null
    _nvm_index_update
end

function _nvm_update --on-event nvm_update
    set --query nvm_mirror || set --universal nvm_mirror https://nodejs.org/dist
    set --query XDG_DATA_HOME || set --local XDG_DATA_HOME ~/.local/share
    set --universal nvm_data $XDG_DATA_HOME/nvm
end

function _nvm_uninstall --on-event nvm_uninstall
    command rm -rf $nvm_data

    set --query nvm_current_version && _nvm_version_deactivate $nvm_current_version

    set --names | string replace --filter --regex -- "^nvm" "set --erase nvm" | source
    functions --erase (functions --all | string match --entire --regex -- "^_nvm_")
end

function _nvm_auto_use --on-event fish_prompt
    if contains -- $argv[1] "install"
        return
    end

    # Check for .tool-versions first (asdf)
    if test -f .tool-versions
        set -l node_version (grep '^nodejs ' .tool-versions | awk '{print $2}')
        if test -n "$node_version"
            set -l current_version (node --version 2>/dev/null | string replace -r '^v' '')
            if test "$node_version" != "$current_version"
                echo "Switching Node from '$current_version' to '$node_version' from .tool-versions (asdf)"
                asdf shell nodejs $node_version
            end
        end
    else if test -f .nvmrc
      #echo "detected .nvmrc file, checking Node version..."
        set nvm_version (string trim < .nvmrc | string replace -r '^v' '')
        set current_version (nvm current | string replace -r '^v' '')

        set nvm_parts (string split '.' $nvm_version)
        set current_parts (string split '.' $current_version)

        set nvm_parts_count (count $nvm_parts)

        switch $nvm_parts_count
            case 3
              #echo "3 parts: $nvm_parts, current: $current_parts"
                if test $nvm_version != $current_version
                    echo "Switching Node from '$current_version' to '$nvm_version' from .nvmrc"
                    nvm use "v$nvm_version"
                end

            case 2
              #echo "2 parts: $nvm_parts, current: $current_parts"
                if test "$nvm_parts[1].$nvm_parts[2]" != "$current_parts[1].$current_parts[2]"
                    echo "Switching Node from '$current_version' to '$nvm_version' from .nvmrc"
                    nvm use "v$nvm_version"
                end

            case 1
              #echo "1 part: $nvm_parts, current: $current_parts"
                if test $nvm_parts[1] != $current_parts[1]
                    echo "Switching Node from '$current_version' to '$nvm_version' from .nvmrc"
                    nvm use "v$nvm_version"
                end

            case '*'
                echo "Unexpected version format in .nvmrc: '$nvm_version'"
        end
    end
end


# Use the default version if none is set when Fish starts interactively
if status is-interactive && set --query nvm_default_version && ! set --query nvm_current_version
    nvm use --silent $nvm_default_version
end

