# PATH setup
__tool_add_path "usr-local-bin" "/usr/local/bin" path prepend
__tool_add_path "usr-local-sbin" "/usr/local/sbin" path prepend
__tool_add_path "homebrew-bin" "/opt/homebrew/bin" path prepend
__tool_add_path "homebrew-sbin" "/opt/homebrew/sbin" path prepend
__tool_add_path "home-bin" "$HOME/bin" path prepend

# Pager
export PAGER="$(whence -p less) -X -F"

# TTY
export TTY=$(tty)

# Add pyenv to PATH (init happens later)
__tool_add_path "pyenv-bin" "$HOME/.pyenv/bin" path prepend

__tool_add_path "cargo-bin" "$HOME/.cargo/bin" path append
if ! __tool_add_path "mysql-homebrew" "/opt/homebrew/mysql/bin" path append; then
  __tool_add_path "mysql-local" "/usr/local/mysql/bin" path append
fi
__tool_add_path "git-credential-manager" "$HOME/apps/git-credential-manager" path append
__tool_add_path "maven-bin" "$HOME/apps/maven/bin" path append

# Perl configuration
if __tool_check_path "perl5-home" "$HOME/perl5" integration dir; then
  __tool_add_path "perl5-bin" "$HOME/perl5/bin" path prepend
  export PERL5LIB="$HOME/perl5/lib/perl5:$PERL5LIB"
  export PERL_LOCAL_LIB_ROOT="$HOME/perl5:$PERL_LOCAL_LIB_ROOT"
  export PERL_MB_OPT="--install_base \"$HOME/perl5\""
  export PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"
fi

# ls tool chain: cygpath (Windows) > eza > gls (GNU ls) > BSD ls
local is_windows=0
case "$(uname -s)" in
  CYGWIN*|MINGW*|MSYS*) is_windows=1 ;;
esac

if (( is_windows )) && __tool_check_cmd "cygpath" cygpath ls-tools; then
  alias ls="command ls -h --color=auto -I 'NTUSER.DAT*' -I 'ntuser.*'"
  alias ll="ls -l"
  alias la="ls -a"
  alias lal="ls -la"
elif __tool_check_cmd "eza" eza ls-tools; then
  function ls {
    if [[ "$*" == "-Alh" ]]; then
      eza --icons -alg
      print -P "%B%U%F{red}%K{white}Command is lal%f%k%u%b"
    else
      eza "$@"
    fi
  }
  function ll { eza --icons -lg "$@"; }
  function la { eza -a "$@"; }
  function lal { eza --icons -alg "$@"; }
elif __tool_check_cmd "gls" gls ls-tools; then
  alias ls="gls -h --color=auto"
  alias ll="ls -l"
  alias la="ls -a"
  alias lal="ls -la"
else
  alias ls="ls -hG"
  alias ll="ls -l"
  alias la="ls -a"
  alias lal="ls -la"
fi

# Editor chain: SSH uses vim, otherwise neovide > mvim > gvim > vim
if [[ "$SSH_TTY" =~ /dev/.* ]]; then
  __tool_check_cmd "vim" vim editor
  export EDITOR="vim -f"
elif __tool_check_cmd "neovide" neovide editor; then
  export EDITOR="neovide --no-fork 2>/dev/null"
  alias gvim="$EDITOR"
  alias vim="$EDITOR"
elif __tool_check_cmd "mvim" mvim editor; then
  export EDITOR="mvim -f --nomru"
  alias gvim="mvim -f"
  alias vim="mvim -f"
elif __tool_check_cmd "gvim" gvim editor; then
  export EDITOR="gvim -f"
  alias gvim="$EDITOR"
  alias vim="$EDITOR"
else
  __tool_check_cmd "vim" vim editor
  export EDITOR=vim
fi

# pyenv initialization
if __tool_check_cmd "pyenv" pyenv lang-managers; then
  if [[ -f "$HOME/.pyenv/shims/.pyenv-shim" ]]; then
    echo "pyenv: skipping init (stale lock file exists). Run: rm ~/.pyenv/shims/.pyenv-shim" >&2
  else
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    # pyenv-virtualenv (optional)
    if pyenv commands 2>/dev/null | grep -q virtualenv-init; then
      eval "$(pyenv virtualenv-init -)"
    fi
  fi
fi

# rbenv initialization
if __tool_check_cmd "rbenv" rbenv lang-managers; then
  eval "$(rbenv init -)"
fi

# Vi mode
bindkey -v
export KEYTIMEOUT=1

# Cursor shape changes for vi mode
function zle-keymap-select {
  if [[ $KEYMAP == vicmd ]]; then
    echo -ne "\e[\x32 q"  # block cursor
  else
    echo -ne "\e[\x36 q"  # beam cursor
  fi
}

function zle-line-init {
  echo -ne "\e[\x36 q"  # beam cursor
}

zle -N zle-keymap-select
zle -N zle-line-init

# Key bindings
bindkey "^R" history-incremental-search-backward
bindkey "^?" backward-delete-char
bindkey "^W" backward-kill-word
bindkey "^H" backward-delete-char
bindkey "^U" backward-kill-line

# Simple aliases
alias ..="cd .."
alias grep="grep --color=auto"
alias egrep="egrep --color=auto"
alias gs="git status"
alias gd="git diff"
alias gits="git"
alias tidy="json_xs -f json -t json-pretty"
alias g="git"
alias lg="lazygit"
alias ping="/sbin/ping"

# nocorrect aliases
alias gradle='nocorrect gradle'
alias bundle='nocorrect bundle'
alias cpan='nocorrect cpan'
alias which='nocorrect type -a'

# GNU tar on homebrew
if [[ -f /opt/homebrew/bin/gtar ]]; then
  alias tar=/opt/homebrew/bin/gtar
fi

# GPG TTY for interactive shells
if [[ -o interactive ]]; then
  export GPG_TTY=$(tty)
fi

# Android SDK
if [[ -z "$ANDROID_HOME" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
fi
__tool_add_path "android-emulator" "$ANDROID_HOME/emulator" path append
__tool_add_path "android-platform-tools" "$ANDROID_HOME/platform-tools" path append

if [[ -z "$ANDROID_STUDIO_HOME" ]]; then
  export ANDROID_STUDIO_HOME="$HOME/Applications/Android Studio.app"
fi
__tool_add_path "android-studio-bin" "$ANDROID_STUDIO_HOME/Contents/bin" path prepend

# Google Cloud SDK
if [[ -n "$CLOUDSDK_GSUTIL_PYTHON" ]]; then
  export CLOUDSDK_GSUTIL_PYTHON
fi

# pipx
__tool_add_path "pipx-bin" "$HOME/.local/bin" path append

# bun
export BUN_INSTALL="$HOME/.bun"
__tool_add_path "bun-bin" "$BUN_INSTALL/bin" path prepend

# opencode
__tool_add_path "opencode-bin" "$HOME/.opencode/bin" path prepend
