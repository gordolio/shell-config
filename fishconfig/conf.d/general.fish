__tool_add_path "usr-local-bin" "/usr/local/bin" path prepend
__tool_add_path "usr-local-sbin" "/usr/local/sbin" path prepend
__tool_add_path "homebrew-bin" "/opt/homebrew/bin" path prepend
__tool_add_path "homebrew-sbin" "/opt/homebrew/sbin" path prepend
__tool_add_path "home-bin" "$HOME/bin" path prepend

if __tool_check_cmd "brew" brew package-managers
  set -l brew_prefix (brew --prefix)
  __tool_add_fish_complete_path "homebrew-completions" "$brew_prefix/share/fish/completions" completion
  __tool_add_fish_complete_path "homebrew-vendor-completions" "$brew_prefix/share/fish/vendor_completions.d" completion
end

set -x PAGER (which less)" -X -F"

# Add pyenv to PATH (init happens later with other lang managers)
__tool_add_path "pyenv-bin" "$HOME/.pyenv/bin" path prepend

__tool_add_path "cargo-bin" "$HOME/.cargo/bin" path append
if __tool_add_path "mysql-homebrew" "/opt/homebrew/mysql/bin" path append
else if __tool_add_path "mysql-local" "/usr/local/mysql/bin" path append
end
__tool_add_path "git-credential-manager" "$HOME/apps/git-credential-manager" path append
__tool_add_path "maven-bin" "$HOME/apps/maven/bin" path append

set -x TTY (tty)

if __tool_check_path "perlbrew-init" "$HOME/perl5/perlbrew/etc/perlbrew.fish" integration file
  set -gx PERLBREW_ROOT $HOME/perl5/perlbrew
  __tool_add_path "perlbrew-bin" "$PERLBREW_ROOT/bin" path prepend
end

if __tool_check_path "perl5-home" "$HOME/perl5" integration dir
  __tool_add_path "perl5-bin" "$HOME/perl5/bin" path prepend
  set -x PERL5LIB "$HOME/perl5/lib/perl5" $PERL5LIB
  set -x PERL_LOCAL_LIB_ROOT "$HOME/perl5" $PERL_LOCAL_LIB_ROOT
  set -x PERL_MB_OPT "--install_base \"$HOME/perl5\""
  set -x PERL_MM_OPT "INSTALL_BASE=$HOME/perl5"
end

# ls tool chain: cygpath (Windows) > eza > gls (GNU ls) > BSD ls
# Only check for cygpath on Windows/Cygwin
set -l is_windows 0
if string match -q 'CYGWIN*' (uname -s); or string match -q 'MINGW*' (uname -s); or string match -q 'MSYS*' (uname -s)
  set is_windows 1
end

if test $is_windows -eq 1; and __tool_check_cmd "cygpath" cygpath ls-tools
  # cygwin has the GNU version of ls
  alias ls "command ls -h --color=auto -I NTUSER.DAT\* -I ntuser.\*"
  alias ll "ls -l"
  alias la "ls -a"
  alias lal "ls -la"
else if __tool_check_cmd "eza" eza ls-tools
  function ls
    if test "$argv" = '-Alh'
      eza --icons -alg
      set_color --bold --italics --underline --background brwhite brred
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
else if __tool_check_cmd "gls" gls ls-tools
  # when on homebrew, use GNU ls if it's installed
  alias ls "gls -h --color=auto"
  alias ll "ls -l"
  alias la "ls -a"
  alias lal "ls -la"
else
  # fallback to BSD ls
  alias ls "ls -hG"
  alias ll "ls -l"
  alias la "ls -a"
  alias lal "ls -la"
end

# Editor chain: SSH uses vim, otherwise neovide > mvim > gvim > vim
if string match -r -q '/dev/.*' $SSH_TTY
  __tool_check_cmd "vim" vim editor
  set -x EDITOR "vim -f"
else if __tool_check_cmd "neovide" neovide editor
  set -x EDITOR "neovide --no-fork 2>/dev/null"
  alias gvim $EDITOR
  alias vim $EDITOR
else if __tool_check_cmd "mvim" mvim editor
  set -x EDITOR "mvim -f --nomru"
  alias gvim "mvim -f"
  alias vim "mvim -f"
else if __tool_check_cmd "gvim" gvim editor
  set -x EDITOR "gvim -f"
  alias gvim $EDITOR
  alias vim $EDITOR
else
  __tool_check_cmd "vim" vim editor
  set -x EDITOR vim
end

# pyenv initialization
if __tool_check_cmd "pyenv" pyenv lang-managers
  status --is-interactive; and pyenv init --path | source
  status --is-interactive; and pyenv init - | source
  # pyenv-virtualenv (optional)
  status --is-interactive; and pyenv virtualenv-init - | source
end

# nvm is initialized by its own conf.d/nvm.fish, just record for ls-tools
functions -q nvm; and __tool_record "nvm" lang-managers loaded nvm ""

alias gd "git diff"

fish_vi_key_bindings
