

set -x PATH $HOME/src/v8-build/depot_tools $PATH
if [ -d /opt/homebrew/bin ]
  set -x PATH /opt/homebrew/bin $PATH
end
if [ -d /opt/homebrew/sbin ]
  set -x PATH /opt/homebrew/sbin $PATH
end
set -x PATH /usr/local/bin /usr/local/sbin $PATH $HOME/bin

if [ -d $HOME/.cargo/bin ]
  set -x PATH $PATH $HOME/.cargo/bin
end
if [ -d /usr/local/mysql/bin ]
   set -x PATH $PATH /usr/local/mysql/bin
end
if [ -d $HOME/apps/git-credential-manager ]
   set -x PATH $PATH $HOME/apps/git-credential-manager
end
if [ -d $HOME/apps/maven/bin ]
   set -x PATH $PATH $HOME/apps/maven/bin
end

if [ -d $HOME/Library/Android/sdk/platform-tools ]
   set -x PATH $PATH $HOME/Library/Android/sdk/platform-tools
end

set -x TTY (tty)

if [ -f $HOME/src/shell-config/tokens/github_token.txt ]
   set -x HOMEBREW_GITHUB_API_TOKEN (cat $HOME/src/shell-config/tokens/github_token.txt)
end

#set -x RUBY_CONFIGURE_OPTS --with-open

# BEGIN
# perlbrew bashrc not compatible with fish
#if test -f $HOME/perl5/perlbrew/etc/bashrc
#   source ~/perl5/perlbrew/etc/bashrc
#   perlbrew switch perl-5.28.2
#end
set -x PATH "$HOME/perl5/bin" $PATH
set -x PERL5LIB "$HOME/perl5/lib/perl5" $PERL5LIB
set -x PERL_LOCAL_LIB_ROOT "$HOME/perl5" $PERL_LOCAL_LIB_ROOT
set -x PERL_MB_OPT "--install_base \"$HOME/perl5\""
set -x PERL_MM_OPT "INSTALL_BASE=$HOME/perl5"
# END

which cygpath 2>&1 > /dev/null
set -l which_cygpath_exit_code $status

which gls 2>&1 > /dev/null
set -l which_gls_exit_code $status

which exa 2>&1 > /dev/null
set -l which_exa_exit_code $status

if [ $which_cygpath_exit_code = 0 ]
  # cygwin has the GNU version of ls
  alias ls "command ls -h --color=auto -I NTUSER.DAT\* -I ntuser.\*"
else if [ $which_exa_exit_code = 0 ]
  set -l exa (which exa)
  function ls
    if [ "$argv" = '-Alh' ]
      exa -alg
      set_color --bold --italics --underline --background brwhite brred;
      echo "Command is lal"
      set_color normal
    else
      exa $argv
    end
  end
  alias ll="$exa -lg"
  alias la="$exa -a"
  alias lal="$exa -alg"
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


# open mvim instead of vim
which mvim 2>&1 > /dev/null
set -l has_mvim_exit_code $status
which gvim 2>&1 > /dev/null
set -l has_gvim_exit_code $status

if string match -r -q '/dev/.*' $SSH_TTY
  set -l is_ssh 1
  set -l vim (which vim)
  set -x EDITOR "$vim -f"
else if [ $has_mvim_exit_code = 0 ]
  set -l vim (which mvim)
  set -x EDITOR "$vim -f"
  alias gvim $EDITOR
  alias vim $EDITOR
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
set -g theme_display_user yes
set -g theme_hide_hostname no


status --is-interactive; and source (pyenv init -|psub)

