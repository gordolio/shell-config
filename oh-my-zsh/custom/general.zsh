#!/usr/bin/zsh

export PATH="/usr/local/sbin:$PATH:/usr/local/mysql/bin:$HOME/bin:$HOME/apps/maven/bin"

export TTY=`tty`

if [[ -f $HOME/.oh-my-zsh/custom/github_token.txt ]]; then
    export HOMEBREW_GITHUB_API_TOKEN=`cat $HOME/.oh-my-zsh/custom/github_token.txt`
fi

if [[ -f ~/perl5/perlbrew/etc/bashrc ]]; then
   source ~/perl5/perlbrew/etc/bashrc
   perlbrew switch perl-5.24.0
fi
if [[ -f $HOME/.rakudobrew/bin/rakudobrew ]]; then
   eval "$($HOME/.rakudobrew/bin/rakudobrew init -)"
fi

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

LS_COMMON="-hG"
LS_COMMON="$LS_COMMON --color=auto"
which cygpath 2>&1 > /dev/null
if [[ $? == 0 ]]; then
   LS_COMMON="$LS_COMMON -I NTUSER.DAT\* -I ntuser.\*"
fi
test -n "$LS_COMMON" &&
alias ls="command ls $LS_COMMON"
alias ll="ls -l"
alias la="ls -a"
alias lal="ll -a"

which mvim 2>&1 > /dev/null
HAS_MVIM_EXIT_CODE=$?
which gvim 2>&1 > /dev/null
HAS_GVIM_EXIT_CODE=$?
if [[ $SSH_TTY =~ /dev/.* ]]; then
  IS_SSH=1
  export EDITOR="vim"
elif [[ $HAS_MVIM_EXIT_CODE = 0 ]]; then
  export EDITOR="`which mvim`"
  alias gvim"$EDITOR"
  alias vim=$EDITOR
elif [[ $HAS_GVIM_EXIT_CODE = 0 ]]; then
  export EDITOR="gvim -f"
  alias vim=$EDITOR
else
   export EDITOR="vim"
fi

if [ -f $HOME/.sdkman/bin/sdkman-init.sh ]; then
   source ~/.sdkman/bin/sdkman-init.sh
fi

which rbenv 2>&1 > /dev/null
if [ $? = 0 ]; then
   eval "$(rbenv init -)"
fi


