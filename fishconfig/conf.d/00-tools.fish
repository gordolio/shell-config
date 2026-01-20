# Tool registry and helpers for startup checks

set -g __tool_names
set -g __tool_categories
set -g __tool_statuses
set -g __tool_details
set -g __tool_paths

function __tool_record
  set -l name $argv[1]
  set -l category $argv[2]
  set -l tool_status $argv[3]
  set -l detail $argv[4]
  set -l path $argv[5]

  set -ga __tool_names $name
  set -ga __tool_categories $category
  set -ga __tool_statuses $tool_status
  set -ga __tool_details $detail
  set -ga __tool_paths $path
end

function __tool_check_cmd
  set -l name $argv[1]
  set -l cmd $argv[2]
  set -l category $argv[3]

  if type -q $cmd
    __tool_record $name $category loaded $cmd ""
    return 0
  end

  __tool_record $name $category missing $cmd ""
  return 1
end

function __tool_check_path
  set -l name $argv[1]
  set -l path $argv[2]
  set -l category $argv[3]
  set -l kind $argv[4]

  if test -z "$path"
    __tool_record $name $category missing empty-path ""
    return 1
  end

  if test "$kind" = file
    if test -f "$path"
      __tool_record $name $category present $path $path
      return 0
    end
  else
    if test -d "$path"
      __tool_record $name $category present $path $path
      return 0
    end
  end

  __tool_record $name $category missing $path $path
  return 1
end

function __tool_source
  set -l name $argv[1]
  set -l path $argv[2]
  set -l category $argv[3]

  if test -f "$path"
    source "$path"
    __tool_record $name $category sourced $path $path
    return 0
  end

  __tool_record $name $category missing $path $path
  return 1
end

function __tool_add_path
  set -l name $argv[1]
  set -l path $argv[2]
  set -l category $argv[3]
  set -l position $argv[4]

  if test -z "$path"
    __tool_record $name $category missing empty-path ""
    return 1
  end

  if test -d "$path"
    if not contains -- "$path" $PATH
      if test "$position" = prepend
        set -gx PATH "$path" $PATH
      else
        set -gx PATH $PATH "$path"
      end
      __tool_record $name $category added $path $path
    else
      __tool_record $name $category already_present $path $path
    end
    return 0
  end

  __tool_record $name $category missing $path $path
  return 1
end

function __tool_add_fish_complete_path
  set -l name $argv[1]
  set -l path $argv[2]
  set -l category $argv[3]

  if test -z "$path"
    __tool_record $name $category missing empty-path ""
    return 1
  end

  if test -d "$path"
    if not contains -- "$path" $fish_complete_path
      set -gx fish_complete_path $fish_complete_path "$path"
      __tool_record $name $category added $path $path
    else
      __tool_record $name $category already_present $path $path
    end
    return 0
  end

  __tool_record $name $category missing $path $path
  return 1
end

function __tool_check_symlink
  set -l name $argv[1]
  set -l link_path $argv[2]
  set -l expected_target $argv[3]
  set -l category $argv[4]

  # Expand ~ in paths
  set link_path (string replace '~' $HOME $link_path)
  set expected_target (string replace '~' $HOME $expected_target)

  if not test -L "$link_path"
    if test -e "$link_path"
      __tool_record $name $category not_symlink "$link_path exists but is not a symlink" $link_path
    else
      __tool_record $name $category missing "$link_path does not exist" $link_path
    end
    return 1
  end

  set -l actual_target (readlink "$link_path")
  # Expand ~ in actual target if present
  set actual_target (string replace '~' $HOME $actual_target)

  if test "$actual_target" = "$expected_target"
    __tool_record $name $category linked "$link_path -> $expected_target" $link_path
    return 0
  else
    __tool_record $name $category wrong_target "$link_path -> $actual_target (expected $expected_target)" $link_path
    return 1
  end
end

function __check_setup_symlinks
  set -l category "symlinks"
  set -l shell_config "$HOME/src/shell-config"

  __tool_check_symlink ".vim" "$HOME/.vim" "$shell_config/vimconfig" $category
  __tool_check_symlink ".vimrc" "$HOME/.vimrc" "$shell_config/vimconfig/vimrc" $category
  __tool_check_symlink ".zshrc" "$HOME/.zshrc" "$shell_config/zshconfig/zshrc" $category
  __tool_check_symlink ".gitconfig" "$HOME/.gitconfig" "$shell_config/gitconfig/gitconfig" $category
  __tool_check_symlink ".config/fish" "$HOME/.config/fish" "$shell_config/fishconfig" $category
end

function __fix_symlink
  set -l link_path $argv[1]
  set -l target $argv[2]
  set -l name $argv[3]

  if test -L "$link_path"
    # It's a symlink, remove it first
    rm "$link_path"
    echo "Removed existing symlink: $link_path"
  else if test -e "$link_path"
    # Something exists but it's not a symlink - back it up
    set -l backup "$link_path.backup"
    mv "$link_path" "$backup"
    echo "Backed up existing file to: $backup"
  end

  # Create parent directory if needed
  set -l parent_dir (dirname "$link_path")
  if not test -d "$parent_dir"
    mkdir -p "$parent_dir"
    echo "Created directory: $parent_dir"
  end

  # Create the symlink
  ln -s "$target" "$link_path"
  if test $status -eq 0
    set_color green
    echo "✅ Created symlink: $link_path -> $target"
    set_color normal
  else
    set_color red
    echo "❌ Failed to create symlink: $link_path"
    set_color normal
    return 1
  end
end

function __fix_setup_symlinks
  set -l shell_config "$HOME/src/shell-config"

  echo "Fixing symlinks..."
  echo ""

  __fix_symlink "$HOME/.vim" "$shell_config/vimconfig" ".vim"
  __fix_symlink "$HOME/.vimrc" "$shell_config/vimconfig/vimrc" ".vimrc"
  __fix_symlink "$HOME/.zshrc" "$shell_config/zshconfig/zshrc" ".zshrc"
  __fix_symlink "$HOME/.gitconfig" "$shell_config/gitconfig/gitconfig" ".gitconfig"
  __fix_symlink "$HOME/.config/fish" "$shell_config/fishconfig" ".config/fish"

  echo ""
  echo "Done. Refreshing symlink status..."

  # Clear existing symlink records and re-check
  set -l new_names
  set -l new_categories
  set -l new_statuses
  set -l new_details
  set -l new_paths

  for index in (seq (count $__tool_names))
    if test "$__tool_categories[$index]" != "symlinks"
      set -a new_names $__tool_names[$index]
      set -a new_categories $__tool_categories[$index]
      set -a new_statuses $__tool_statuses[$index]
      set -a new_details $__tool_details[$index]
      set -a new_paths $__tool_paths[$index]
    end
  end

  set -g __tool_names $new_names
  set -g __tool_categories $new_categories
  set -g __tool_statuses $new_statuses
  set -g __tool_details $new_details
  set -g __tool_paths $new_paths

  __check_setup_symlinks
end

# Run symlink checks at startup
__check_setup_symlinks

function ls-tools
  if contains -- --fix-links $argv
    __fix_setup_symlinks
    echo ""
  end

  if not set -q __tool_names[1]
    echo "No tools recorded for this session."
    return 0
  end

  set -l categories (printf "%s\n" $__tool_categories | sort -u)

  for category in $categories
    set_color --bold
    echo $category
    set_color normal

    for index in (seq (count $__tool_names))
      if test "$__tool_categories[$index]" = "$category"
        set -l name $__tool_names[$index]
        set -l tool_status $__tool_statuses[$index]
        set -l detail $__tool_details[$index]
        set -l path $__tool_paths[$index]
        set -l info $name

        if test -n "$path"
          set info "$info ($path)"
        else if test -n "$detail"
          set info "$info ($detail)"
        end

        if test "$tool_status" = missing
          set_color red
          echo -n "❌ "
        else if test "$tool_status" = already_present
          set_color yellow
          echo -n "⏭  "
        else if test "$tool_status" = not_symlink; or test "$tool_status" = wrong_target
          set_color red
          echo -n "⚠️  "
        else
          set_color green
          echo -n "✅ "
        end
        set_color normal

        echo "$info - $tool_status"
      end
    end

    echo ""
  end
end
