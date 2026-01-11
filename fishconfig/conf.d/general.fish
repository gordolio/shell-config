

#depot_tools is now in src/chromium/depot_tools
#set -x PATH $HOME/src/v8-build/depot_tools $PATH

__tool_add_path "usr-local-bin" "/usr/local/bin" path prepend
__tool_add_path "usr-local-sbin" "/usr/local/sbin" path prepend
__tool_add_path "homebrew-bin" "/opt/homebrew/bin" path prepend
__tool_add_path "homebrew-sbin" "/opt/homebrew/sbin" path prepend
__tool_add_path "home-bin" "$HOME/bin" path prepend

#if [ -d $HOME/.claude/local ]
#  set -x PATH $HOME/.claude/local $PATH
#end

#if [ -d $HOME/src/emsdk ]
#  set -x PATH $HOME/src/emsdk $HOME/src/emsdk/node/14.15.5_64bit/bin $HOME/src/emsdk/upstream/emscripten $PATH
#end


if type -q brew
  set -l brew_prefix (brew --prefix)
  __tool_add_fish_complete_path "homebrew-completions" "$brew_prefix/share/fish/completions" completion
  __tool_add_fish_complete_path "homebrew-vendor-completions" "$brew_prefix/share/fish/vendor_completions.d" completion
end

set -x PAGER (which less)" -X -F"

#set -x PATH (python3 -m site --user-base)/bin $PATH

# Add pyenv to PATH
if __tool_add_path "pyenv-bin" "$HOME/.pyenv/bin" path prepend
  # Initialize pyenv (required)
  status --is-interactive; and pyenv init --path | source
  status --is-interactive; and pyenv init - | source

  # Initialize pyenv-virtualenv (optional)
  status --is-interactive; and pyenv virtualenv-init - | source
end




__tool_add_path "cargo-bin" "$HOME/.cargo/bin" path append
if __tool_add_path "mysql-homebrew" "/opt/homebrew/mysql/bin" path append
else if __tool_add_path "mysql-local" "/usr/local/mysql/bin" path append
end
__tool_add_path "git-credential-manager" "$HOME/apps/git-credential-manager" path append
__tool_add_path "maven-bin" "$HOME/apps/maven/bin" path append

set -x TTY (tty)

#set -x RUBY_CONFIGURE_OPTS --with-open

# BEGIN
if __tool_check_path "perlbrew-init" "$HOME/perl5/perlbrew/etc/perlbrew.fish" integration file
   set -gx PERLBREW_ROOT $HOME/perl5/perlbrew
   __tool_add_path "perlbrew-bin" "$PERLBREW_ROOT/bin" path prepend
   #perlbrew switch perl-5.34.0
end

if __tool_check_path "perl5-home" "$HOME/perl5" integration dir
  __tool_add_path "perl5-bin" "$HOME/perl5/bin" path prepend
  set -x PERL5LIB "$HOME/perl5/lib/perl5" $PERL5LIB
  set -x PERL_LOCAL_LIB_ROOT "$HOME/perl5" $PERL_LOCAL_LIB_ROOT
  set -x PERL_MB_OPT "--install_base \"$HOME/perl5\""
  set -x PERL_MM_OPT "INSTALL_BASE=$HOME/perl5"
end
# END

which cygpath 2>&1 > /dev/null
set -l which_cygpath_exit_code $status

which gls 2>&1 > /dev/null
set -l which_gls_exit_code $status

which eza 2>&1 > /dev/null
set -l which_eza_exit_code $status

if [ $which_cygpath_exit_code = 0 ]
  # cygwin has the GNU version of ls
  alias ls "command ls -h --color=auto -I NTUSER.DAT\* -I ntuser.\*"
else if [ $which_eza_exit_code = 0 ]
  set -l eza (which eza)
  function ls
    #set realCommand ""
    #set realArg ""
    #set matches (string match -ar '\\^(\\-Alh)( ?.*)' $argv)
#
#    if [ $matches ]
#      if [ $matches[1] == '-Alh' ]
#        set realCommand "lal"
#        set realArg "-alg"
#      else if [ $matches[1] == '-Al' ]
#        set realCommand "la"
#        set realArg "-a"
#      else if [ $matches[1] == '-A' ]
#        set realCommand "la"
#        set realArg "-a"
#      end
#    end

#    if [ $realCommand != "" ]
#      if [ $argv ]
#        exa $argv
#      else
#        exa
#      end
#    else
#      exa $realArg $argv
#      set_color --bold --italics --underline --background brwhite brred;
#      echo "Command is $realCommand"
#      set_color normal
#    end
    if [ "$argv" = '-Alh' ]
      eza --icons -alg
      set_color --bold --italics --underline --background brwhite brred;
      echo "Command is lal"
      set_color normal
    else
      eza $argv
    end
  end
  function ll
    eza --icons -lg $argv
  end
  function la
    eza -a $argv
  end
  function lal
    eza --icons -alg $argv
  end
else if [ $which_gls_exit_code = 0 ]
  # when on homebrew, use GNU ls if it's installed
  set -l gls (which gls)
  alias ls "$gls -h --color=auto"
  alias la="ls -a"
  alias lal="ll -a"
else
  # we're on mac and we don't have GNU ls. fallback to bsd
  alias ls "ls -hG"
end


# open neovide instead of vim
which neovide 2>&1 > /dev/null
set -l has_neovide_exit_code $status
which mvim 2>&1 > /dev/null
set -l has_mvim_exit_code $status
which gvim 2>&1 > /dev/null
set -l has_gvim_exit_code $status

if string match -r -q '/dev/.*' $SSH_TTY
  set -l is_ssh 1
  set -l vim (which vim)
  set -x EDITOR "$vim -f"
else if [ $has_neovide_exit_code = 0 ]
  set -l vim (which neovide)
  set -x EDITOR "$vim --no-fork 2>/dev/null"
  alias gvim $EDITOR
  alias vim $EDITOR
else if [ $has_mvim_exit_code = 0 ]
  set -l vim (which mvim)
  set -x EDITOR "$vim -f --nomru"
  alias gvim "$vim -f"
  alias vim "$vim -f"
else if [ $has_gvim_exit_code = 0 ]
  set -l vim (which gvim)
  set -x EDITOR "$vim -f"
  alias gvim $EDITOR
  alias vim $EDITOR
else
  set -x EDITOR vim
end

#set -g cursor_vi_mode_insert bar_blinking

#typeset -Ag FX FG BG
#sets some colors for Ag. I don't believe it's needed for fish


# show username
#set -g theme_display_user yes
#set -g theme_hide_hostname no

which pyenv 2>&1 > /dev/null
set -l which_pyenv_exit_code $status
if [ $which_pyenv_exit_code = 0 ]
  # old method
  # status --is-interactive; and source (pyenv init -|psub)
  # new method
  status is-login; and pyenv init --path | source
  #pyenv init - | source
end

# You must call it on initialization or listening to directory switching won't work
which nvm 2>&1 > /dev/null
set -l which_nvm_exit_code $status
if [ $which_nvm_exit_code = 0 ]
  load_nvm
end

alias gd "git diff"

#set fish_vi_force_cursor 1
fish_vi_key_bindings

