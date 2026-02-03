# Bridge file to source personal configs after Fisher plugins
# This file loads last (zz- prefix) to ensure Fisher plugins are loaded first

set -l personal_dir (dirname (status dirname))/personal.d

if test -d $personal_dir
    # Add personal functions and completions to fish paths
    if test -d $personal_dir/functions
        set -p fish_function_path $personal_dir/functions
    end
    if test -d $personal_dir/completions
        set -p fish_complete_path $personal_dir/completions
    end

    # Source config files
    for file in $personal_dir/*.fish
        source $file
    end
end
