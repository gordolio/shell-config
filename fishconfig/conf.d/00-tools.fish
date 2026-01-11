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

function ls-tools
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
