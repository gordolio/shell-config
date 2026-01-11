# ~/.config/fish/config.fish

alias ip 'curl ipinfo.io/ip'

if type -q brew
  set -l brew_prefix (brew --prefix)

  if __tool_check_cmd "screenfetch" "$brew_prefix/bin/screenfetch" tool
    alias screenfetch="$brew_prefix/bin/screenfetch -D 'Mac OS X'"
  end

  if __tool_check_cmd "oh-my-posh" "$brew_prefix/bin/oh-my-posh" tool
    oh-my-posh init fish --config ~/.config/fish/jandedobbeleer.omp.yaml | source
  end

  if __tool_check_cmd "pyenv" "$brew_prefix/bin/pyenv" tool
    pyenv init - | source
  end
end

if status --is-interactive; and __tool_check_cmd "rbenv" rbenv tool
    rbenv init - fish | source
end

function sshkey
    ssh-copy-id -i ~/.ssh/id_ed25519.pub $argv
end


# Add Conda initialization
# Disabled - not needed for prompt, conda still available via PATH if needed
#if test -d ~/miniconda3/etc/fish/conf.d
#  for file in ~/miniconda3/etc/fish/conf.d/*.fish
#    source $file
#  end
#end

# Set Android SDK environment variables
set -q ANDROID_HOME; or set -x ANDROID_HOME $HOME/Library/Android/sdk

__tool_add_path "android-emulator" "$ANDROID_HOME/emulator" path append
__tool_add_path "android-platform-tools" "$ANDROID_HOME/platform-tools" path append

set -q ANDROID_STUDIO_HOME; or set -x ANDROID_STUDIO_HOME "$HOME/Applications/Android Studio.app"

__tool_add_path "android-studio-bin" "$ANDROID_STUDIO_HOME/Contents/bin" path prepend

function delete_word_or_path
  set -l buffer (commandline -b)
  set -l cursor_pos (commandline -C)
  set -l left_of_cursor (string sub -l 1 $cursor_pos $buffer)
  set -l right_of_cursor (string sub -s (math $cursor_pos + 1) $buffer)
  if test -z "$left_of_cursor"
    return
  end
  set -l last_char (string sub -l -1 $left_of_cursor)
  if test "$last_char" = "/"
    set -l new_buffer (string sub -l 1 -1 $left_of_cursor)
    set -l to_delete (string match -r -e ".*/" $new_buffer)
    set -l new_left_of_cursor (string replace -r -a "$to_delete" "" $new_buffer)
    commandline -r (string join "" $new_left_of_cursor $right_of_cursor)
    commandline -C (string length $new_left_of_cursor)
  else
    commandline -f backward-kill-word
  end
end

bind \e\177 delete_word_or_path

set -Ux CLOUDSDK_GSUTIL_PYTHON /opt/homebrew/opt/python@3.11/bin/python3.11


#check for the existance of phpbrew.fish
#if test -e ~/.phpbrew/phpbrew.fish
#  source ~/.phpbrew/phpbrew.fish
#end



# Created by `pipx` on 2024-12-09 16:17:37
__tool_add_path "pipx-bin" "$HOME/.local/bin" path append

# bun
set --export BUN_INSTALL "$HOME/.bun"
__tool_add_path "bun-bin" "$BUN_INSTALL/bin" path prepend

if status --is-interactive
  set -gx GPG_TTY (tty)
end


# ASDF configuration
__tool_source "asdf" "/opt/homebrew/opt/asdf/libexec/asdf.fish" integration

# The next line updates PATH for the Google Cloud SDK.
__tool_source "google-cloud-sdk" "/opt/homebrew/share/google-cloud-sdk/path.fish.inc" integration

# opencode
__tool_add_path "opencode-bin" "$HOME/.opencode/bin" path prepend
