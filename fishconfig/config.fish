# ~/.config/fish/config.fish

alias ip 'curl ipinfo.io/ip'

if type -q (brew --prefix)/bin/screenfetch
  alias screenfetch=(brew --prefix)"/bin/screenfetch -D 'Mac OS X'"
end

if type -q (brew --prefix)/bin/oh-my-posh
  oh-my-posh init fish --config ~/.config/fish/jandedobbeleer.omp.yaml | source
end

if test -e ~/perl5/perlbrew/etc/perlbrew.fish
  . ~/perl5/perlbrew/etc/perlbrew.fish
end

if type -q (brew --prefix)/bin/pyenv
  pyenv init - | source
end

if status --is-interactive; and command -q rbenv
    rbenv init - fish | source
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

if test -d $ANDROID_HOME/emulator
  if not contains $ANDROID_HOME/emulator $PATH
    set -x PATH $PATH $ANDROID_HOME/emulator
  end
end

if test -d $ANDROID_HOME/platform-tools
  if not contains $ANDROID_HOME/platform-tools $PATH
    set -x PATH $PATH $ANDROID_HOME/platform-tools
  end
end

set -q ANDROID_STUDIO_HOME; or set -x ANDROID_STUDIO_HOME "$HOME/Applications/Android Studio.app"

set -x PATH $ANDROID_STUDIO_HOME/Contents/bin $PATH

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
set PATH $PATH /Users/gordon/.local/bin

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

if status --is-interactive
  set -gx GPG_TTY (tty)
end


# ASDF configuration
if test -f /opt/homebrew/opt/asdf/libexec/asdf.fish
  source /opt/homebrew/opt/asdf/libexec/asdf.fish
end

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/opt/homebrew/share/google-cloud-sdk/path.fish.inc' ]; . '/opt/homebrew/share/google-cloud-sdk/path.fish.inc'; end
