#!/usr/bin/zsh

export PATH="/usr/local/sbin:$PATH:$HOME/bin"

if [[ -d /usr/local/mysql/bin ]]; then
   export PATH="$PATH:/usr/local/mysql/bin"
fi
if [[ -d $HOME/apps/git-credential-manager ]]; then
   export PATH="$PATH:$HOME/apps/git-credential-manager"
fi
if [[ -d $HOME/apps/maven/bin ]]; then
   export PATH="$PATH:$HOME/apps/maven/bin"
fi

if [[ -d /opt/homebrew ]]; then
  export PATH="$PATH:/opt/homebrew/bin"
fi

if [[ -d $HOME/Library/Android/sdk/platform-tools ]]; then
  export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"
fi

export TTY=`tty`

if [[ -f $HOME/.oh-my-zsh/custom/github_token.txt ]]; then
    export HOMEBREW_GITHUB_API_TOKEN=`cat $HOME/.oh-my-zsh/custom/github_token.txt`
fi

# BEGIN
# keep perl modules working between perl upgrades
export PATH="$HOME/perl5/bin:$PATH"
export PERL5LIB="$HOME/perl5/lib/perl5:$PERL5LIB"
export PERL_LOCAL_LIB_ROOT="$HOME/perl5:$PERL_LOCAL_LIB_ROOT"
export PERL_MB_OPT="--install_base \"$HOME/perl5\""
export PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"
# END

bindkey -v
export KEYTIMEOUT=1

typeset -Ag FX FG BG

zle-keymap-select () {
  if [[ $KEYMAP = vicmd ]]; then
    echo -ne "\e[\x32 q"
  else
    echo -ne "\e[\x36 q"
  fi
}

zle-line-init () {
  echo -ne "\e[\x36 q"
}

zle -N zle-keymap-select
zle -N zle-line-init

bindkey "^R" history-incremental-search-backward
bindkey "^?" backward-delete-char
bindkey "^W" backward-kill-word
bindkey "^H" backward-delete-char
bindkey "^U" backward-kill-line

HISTSIZE=3000
if (( ! EUID )); then
  HISTFILE=~/.history_root
else
  HISTFILE=~/.history
fi
SAVEHIST=3000
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

alias ..="cd .."
alias grep="grep --color=auto"
alias egrep="egrep --color=auto"
alias gs="git status"
alias gd="git diff"
alias gits="git"
alias "git clean"="git clean -i"
alias tidy="json_xs -f json -t json-pretty"


which cygpath 2>&1 > /dev/null
WHICH_CYGPATH_EXIT_CODE=$?

# use gnu version of ls (for use on mac when we get gls from homebrew)
which gls 2>&1 > /dev/null
WHICH_GLS_EXIT_CODE=$?

if [[ $WHICH_CYGPATH_EXIT_CODE = 0 ]]; then
  # cygwin has the GNU version of ls
  alias ls="command ls -h --color=auto -I NTUSER.DAT\* -I ntuser.\*"
elif [[ $WHICH_GLS_EXIT_CODE = 0 ]]; then
  # when on homebrew, use GNU ls if it's installed
  alias ls="`which gls` -h --color=auto"
else
  # we're on mac and we don't have GNU ls. fallback to bsd
  alias ls="ls -hG"
fi

alias ll="ls -l"
alias la="ls -a"
alias lal="ll -a"

which vimr 2>&1 > /dev/null
HAS_VIMR_EXIT_CODE=$?
which gvim 2>&1 > /dev/null
HAS_GVIM_EXIT_CODE=$?
if [[ $SSH_TTY =~ /dev/.* ]]; then
  IS_SSH=1
  export EDITOR="`which vim` -f"
elif [[ $HAS_VIMR_EXIT_CODE = 0 ]]; then
  export EDITOR="`which vimr` -f"
  alias gvim"nocorrect $EDITOR"
  alias vim="nocorrect $EDITOR"
elif [[ $HAS_GVIM_EXIT_CODE = 0 ]]; then
  export EDITOR="`which gvim` -f"
  alias gvim="nocorrect $EDITOR"
  alias vim="nocorrect $EDITOR"
else
   export EDITOR="vim"
fi

which rbenv 2>&1 > /dev/null
if [ $? = 0 ]; then
   eval "$(rbenv init -)"
fi


