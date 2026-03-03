# Tool registry and helpers for startup checks

typeset -ga __tool_names
typeset -ga __tool_categories
typeset -ga __tool_statuses
typeset -ga __tool_details
typeset -ga __tool_paths

local __home_icon=$'\e[38;2;91;155;213m\uf015\e[0m '
local __brew_icon=$'\e[38;2;212;160;23m\uf0fc\e[0m '

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
    if [[ ":$PATH:" != *":$dir:"* ]]; then
      if [[ "$position" == "prepend" ]]; then
        export PATH="$dir:$PATH"
      else
        export PATH="$PATH:$dir"
      fi
      __tool_record "$name" "$category" added "$dir" "$dir"
    else
      __tool_record "$name" "$category" already_present "$dir" "$dir"
    fi
    return 0
  fi

  __tool_record "$name" "$category" missing "$dir" "$dir"
  return 1
}

function __tool_check_symlink {
  local name=$1 link_path=$2 expected_target=$3 category=$4

  # Expand ~ in paths
  link_path="${link_path/#\~/$HOME}"
  expected_target="${expected_target/#\~/$HOME}"

  if [[ ! -L "$link_path" ]]; then
    if [[ -e "$link_path" ]]; then
      __tool_record "$name" "$category" not_symlink "$link_path exists but is not a symlink" "$link_path"
    else
      __tool_record "$name" "$category" missing "$link_path does not exist" "$link_path"
    fi
    return 1
  fi

  local actual_target
  actual_target=$(readlink "$link_path")
  actual_target="${actual_target/#\~/$HOME}"

  if [[ "$actual_target" == "$expected_target" ]]; then
    __tool_record "$name" "$category" linked "$link_path -> $expected_target" "$link_path"
    return 0
  else
    __tool_record "$name" "$category" wrong_target "$link_path -> $actual_target (expected $expected_target)" "$link_path"
    return 1
  fi
}

function __check_setup_symlinks {
  local category="symlinks"
  local shell_config="$HOME/src/shell-config"

  __tool_check_symlink ".vim" "$HOME/.vim" "$shell_config/vimconfig" "$category"
  __tool_check_symlink ".vimrc" "$HOME/.vimrc" "$shell_config/vimconfig/vimrc" "$category"
  __tool_check_symlink ".zshrc" "$HOME/.zshrc" "$shell_config/zshconfig/zshrc" "$category"
  __tool_check_symlink ".gitconfig" "$HOME/.gitconfig" "$shell_config/gitconfig/gitconfig" "$category"
  __tool_check_symlink ".config/fish" "$HOME/.config/fish" "$shell_config/fishconfig" "$category"
  __tool_check_symlink ".config/atuin" "$HOME/.config/atuin/config.toml" "$shell_config/atuinconfig/config.toml" "$category"
  __tool_check_symlink ".config/oh-my-posh" "$HOME/.config/oh-my-posh" "$shell_config/oh-my-poshconfig" "$category"
  __tool_check_symlink ".config/nvim" "$HOME/.config/nvim" "$shell_config/nvimconfig" "$category"

  __tool_check_path "claw-header-detect" "$HOME/.claw-header-detect" "$category" dir

  # iTerm2 uses defaults instead of a symlink
  local iterm_prefs_folder
  iterm_prefs_folder=$(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null)
  local iterm_load
  iterm_load=$(defaults read com.googlecode.iterm2 LoadPrefsFromCustomFolder 2>/dev/null)
  if [[ "$iterm_prefs_folder" == "$shell_config/iterm2config" ]] && [[ "$iterm_load" == "1" ]]; then
    __tool_record "iterm2-config" "$category" linked "PrefsCustomFolder -> $shell_config/iterm2config" ""
  else
    __tool_record "iterm2-config" "$category" wrong_target "PrefsCustomFolder=${iterm_prefs_folder:-unset}, LoadPrefs=${iterm_load:-0}" ""
  fi
}

function __fix_symlink {
  local link_path=$1 target=$2 name=$3

  local display_link="${link_path//$HOME/$__home_icon}"
  display_link="${display_link//\/opt\/homebrew/$__brew_icon}"
  local display_target="${target//$HOME/$__home_icon}"
  display_target="${display_target//\/opt\/homebrew/$__brew_icon}"

  # Check if symlink already exists and is correct
  if [[ -L "$link_path" ]]; then
    local actual_target
    actual_target=$(readlink "$link_path")
    if [[ "$actual_target" == "$target" ]]; then
      echo "✅ $display_link -> $display_target (ok)"
      return 0
    fi
    local display_actual="${actual_target//$HOME/$__home_icon}"
    display_actual="${display_actual//\/opt\/homebrew/$__brew_icon}"
    rm "$link_path"
    echo "🔧 $display_link -> $display_target (was: $display_actual)"
  elif [[ -e "$link_path" ]]; then
    local backup="$link_path.backup"
    mv "$link_path" "$backup"
    echo "🔧 $display_link -> $display_target (backed up existing file)"
  else
    echo "🔧 $display_link -> $display_target (created)"
  fi

  # Create parent directory if needed
  local parent_dir
  parent_dir=$(dirname "$link_path")
  if [[ ! -d "$parent_dir" ]]; then
    mkdir -p "$parent_dir"
  fi

  if ! ln -s "$target" "$link_path"; then
    echo "❌ Failed to create symlink: $display_link"
    return 1
  fi
}

function __fix_setup_symlinks {
  local shell_config="$HOME/src/shell-config"

  echo "Checking symlinks..."
  echo ""

  __fix_symlink "$HOME/.vim" "$shell_config/vimconfig" ".vim"
  __fix_symlink "$HOME/.vimrc" "$shell_config/vimconfig/vimrc" ".vimrc"
  __fix_symlink "$HOME/.zshrc" "$shell_config/zshconfig/zshrc" ".zshrc"
  __fix_symlink "$HOME/.gitconfig" "$shell_config/gitconfig/gitconfig" ".gitconfig"
  __fix_symlink "$HOME/.config/fish" "$shell_config/fishconfig" ".config/fish"
  __fix_symlink "$HOME/.config/atuin/config.toml" "$shell_config/atuinconfig/config.toml" ".config/atuin"
  __fix_symlink "$HOME/.config/oh-my-posh" "$shell_config/oh-my-poshconfig" ".config/oh-my-posh"
  __fix_symlink "$HOME/.config/nvim" "$shell_config/nvimconfig" ".config/nvim"

  # Claude header detection directory
  if [[ -d "$HOME/.claw-header-detect" ]]; then
    echo "✅ ${__home_icon}/.claw-header-detect (ok)"
  else
    mkdir -p "$HOME/.claw-header-detect"
    echo "🔧 ${__home_icon}/.claw-header-detect (created)"
  fi

  # iTerm2: configure via defaults
  echo ""
  local iterm_prefs_folder iterm_load
  iterm_prefs_folder=$(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null)
  iterm_load=$(defaults read com.googlecode.iterm2 LoadPrefsFromCustomFolder 2>/dev/null)
  if [[ "$iterm_prefs_folder" == "$shell_config/iterm2config" ]] && [[ "$iterm_load" == "1" ]]; then
    echo "✅ iTerm2 -> ${shell_config//$HOME/$__home_icon}iterm2config (ok)"
  else
    defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$shell_config/iterm2config"
    defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
    echo "🔧 iTerm2 -> ${shell_config//$HOME/$__home_icon}iterm2config (fixed)"
  fi
  # Also set up the git clean filter for this repo
  git -C "$shell_config" config filter.iterm2-sanitize.clean 'iterm2config/iterm2-sanitize.sh'

  echo ""
  echo "Done. Refreshing symlink status..."

  # Clear existing symlink records and re-check
  local -a new_names new_categories new_statuses new_details new_paths
  local i
  for (( i=1; i<=${#__tool_names[@]}; i++ )); do
    if [[ "${__tool_categories[$i]}" != "symlinks" ]]; then
      new_names+=("${__tool_names[$i]}")
      new_categories+=("${__tool_categories[$i]}")
      new_statuses+=("${__tool_statuses[$i]}")
      new_details+=("${__tool_details[$i]}")
      new_paths+=("${__tool_paths[$i]}")
    fi
  done

  __tool_names=("${new_names[@]}")
  __tool_categories=("${new_categories[@]}")
  __tool_statuses=("${new_statuses[@]}")
  __tool_details=("${new_details[@]}")
  __tool_paths=("${new_paths[@]}")

  __check_setup_symlinks
}

# Run symlink checks at startup
__check_setup_symlinks

# Check plugin manager
if (( $+commands[zinit] )) || (( $+functions[zinit] )); then
  __tool_record "zinit" "plugin-managers" loaded "zinit" ""
else
  __tool_record "zinit" "plugin-managers" missing "zinit" ""
fi

function ls-tools {
  if [[ " $* " == *" --fix-links "* || " $* " == *" --fix "* ]]; then
    __fix_setup_symlinks
    echo ""
  fi

  if (( ${#__tool_names[@]} == 0 )); then
    echo "No tools recorded for this session."
    return 0
  fi

  # Get unique categories (sorted)
  local -a categories
  categories=($(printf "%s\n" "${__tool_categories[@]}" | sort -u))

  local category i name tool_status detail tool_path info
  for category in "${categories[@]}"; do
    print -P "%B$category%b"

    for (( i=1; i<=${#__tool_names[@]}; i++ )); do
      if [[ "${__tool_categories[$i]}" == "$category" ]]; then
        name="${__tool_names[$i]}"
        tool_status="${__tool_statuses[$i]}"
        detail="${__tool_details[$i]}"
        tool_path="${__tool_paths[$i]}"
        info="$name"

        if [[ -n "$tool_path" ]]; then
          info="$info ($tool_path)"
        elif [[ -n "$detail" ]]; then
          info="$info ($detail)"
        fi

        case "$tool_status" in
          missing)
            print -Pn "%F{red}❌ %f" ;;
          already_present)
            print -Pn "%F{yellow}⏭  %f" ;;
          not_symlink|wrong_target)
            print -Pn "%F{red}⚠️  %f" ;;
          *)
            print -Pn "%F{green}✅ %f" ;;
        esac

        info="${info//$HOME/$__home_icon}"
        info="${info//\/opt\/homebrew/$__brew_icon}"
        echo "$info - $tool_status"
      fi
    done

    echo ""
  done

  if (( $+commands[zinit] )) || (( $+functions[zinit] )); then
    print -P "%BUpdate shell plugins with:%b  zinit update"
  else
    print -P "%B%F{red}Install zinit with:%f%b  git clone https://github.com/zdharma-continuum/zinit.git \"\${XDG_DATA_HOME:-\${HOME}/.local/share}/zinit/zinit.git\""
  fi
}
