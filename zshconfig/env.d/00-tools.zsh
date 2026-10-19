# Tool registry and helpers for startup checks

typeset -ga __tool_names
typeset -ga __tool_categories
typeset -ga __tool_statuses
typeset -ga __tool_details
typeset -ga __tool_paths

function __tool_record {
  local name=$1 category=$2 tool_status=$3 detail=$4 tool_path=$5

  __tool_names+=("$name")
  __tool_categories+=("$category")
  __tool_statuses+=("$tool_status")
  __tool_details+=("$detail")
  __tool_paths+=("$tool_path")
}

function __tool_check_cmd {
  local name=$1 cmd=$2 category=$3

  if command -v "$cmd" &>/dev/null; then
    __tool_record "$name" "$category" loaded "$cmd" ""
    return 0
  fi

  __tool_record "$name" "$category" missing "$cmd" ""
  return 1
}

function __tool_check_path {
  local name=$1 dir=$2 category=$3 kind=$4

  if [[ -z "$dir" ]]; then
    __tool_record "$name" "$category" missing "empty-path" ""
    return 1
  fi

  if [[ "$kind" == "file" ]]; then
    if [[ -f "$dir" ]]; then
      __tool_record "$name" "$category" present "$dir" "$dir"
      return 0
    fi
  else
    if [[ -d "$dir" ]]; then
      __tool_record "$name" "$category" present "$dir" "$dir"
      return 0
    fi
  fi

  __tool_record "$name" "$category" missing "$dir" "$dir"
  return 1
}

function __tool_source {
  local name=$1 file=$2 category=$3

  if [[ -f "$file" ]]; then
    source "$file"
    __tool_record "$name" "$category" sourced "$file" "$file"
    return 0
  fi

  __tool_record "$name" "$category" missing "$file" "$file"
  return 1
}

function __tool_add_path {
  # NOTE: cannot use "local path" — zsh's $path is tied to $PATH
  local name=$1 dir=$2 category=$3 position=${4:-append}

  if [[ -z "$dir" ]]; then
    __tool_record "$name" "$category" missing "empty-path" ""
    return 1
  fi

  if [[ -d "$dir" ]]; then
    local tool_status=added
    (( ${path[(Ie)$dir]} )) && tool_status=already_present

    if [[ "$position" == "prepend" ]]; then
      # Move to the front even when already present. Login shells run macOS's
      # path_helper (/etc/zprofile) first, which pushes an inherited PATH behind
      # /usr/bin; leaving entries in place would let Apple's git/perl/python win
      # in nested login shells and agents started from a terminal.
      path=("$dir" "${(@)path:#${(b)dir}}")
    elif [[ "$tool_status" == added ]]; then
      path+=("$dir")
    fi
    __tool_record "$name" "$category" "$tool_status" "$dir" "$dir"
    return 0
  fi

  __tool_record "$name" "$category" missing "$dir" "$dir"
  return 1
}

