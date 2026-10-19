# Interactive-only settings. PATH and exports agents also need are in
# env.d/general.zsh.

# When zsh isn't the macOS login shell (iTerm2 runs it as a profile command),
# SHELL still names the login shell. Point it at zsh so tools that start "your
# shell" from here (tmux, vim's :terminal, Codex, completion generators) get zsh.
[[ $SHELL == */zsh ]] || export SHELL=${commands[zsh]:-/bin/zsh}

# TTY
export TTY=$(tty)

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
  # neovide has its own clap-based CLI parser, unlike real vim binaries; vim-style
  # flags (-R, -u, -c, ...) must go after `--` to reach the wrapped nvim process.
  # But plain filenames must NOT go after `--`: neovide only runs its own
  # focus-switch logic for files given as its leading FILES_TO_OPEN args.
  # Anything shoved into the `--`-separated NEOVIM_ARGS instead gets added as
  # an unloaded, unfocused buffer, leaving neovide's own intro-screen buffer
  # active as "[No Name]" next to it (reproduced: `neovide --no-fork -- file`
  # leaves two buffers with the file unfocused; `neovide --no-fork file`
  # opens straight into it).
  __vim_neovide() {
    for a in "$@"; do
      if [[ "$a" == -* ]]; then
        neovide --no-fork -- "$@" 2>/dev/null
        return
      fi
    done
    neovide --no-fork "$@" 2>/dev/null
  }
  vim() { __vim_neovide "$@" }
  gvim() { __vim_neovide "$@" }
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

# pyenv shell function and completions (shims are already on PATH from env.d).
# Cached, and `--no-rehash` skips the per-start rehash: pyenv rehashes after its
# own installs, and `pyenv rehash` is there for anything else.
if (( $+commands[pyenv] )); then
  if [[ -f "$HOME/.pyenv/shims/.pyenv-shim" ]]; then
    echo "pyenv: stale lock file makes rehash hang. Run: rm ~/.pyenv/shims/.pyenv-shim" >&2
  fi
  __cached_eval pyenv pyenv pyenv init - --no-push-path --no-rehash zsh
  # pyenv-virtualenv (optional)
  if (( $+commands[pyenv-virtualenv-init] )); then
    __cached_eval pyenv-virtualenv pyenv-virtualenv-init pyenv virtualenv-init - zsh
  fi
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

# Alt-Backspace deletes one path segment ("src/shell-config/" -> "src/"), where
# ^W takes the whole path.
function __backward_kill_path_segment {
  local WORDCHARS=${WORDCHARS//\/}
  zle backward-kill-word
}
zle -N __backward_kill_path_segment

# Key bindings
bindkey "^R" history-incremental-search-backward
bindkey "^?" backward-delete-char
bindkey "^W" backward-kill-word
bindkey "^H" backward-delete-char
bindkey "^U" backward-kill-line
bindkey "^[^?" __backward_kill_path_segment

# cd looks in the current directory, then home (`cd src` works from anywhere)
cdpath=(. ~)

# fzf: fd-backed file and directory sources for Ctrl-T / Alt-C and plain `fzf`
if __tool_check_cmd "fd" fd search-tools; then
  export FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND:-fd --type f --hidden --follow --exclude .git}"
  FZF_CTRL_T_COMMAND="${FZF_CTRL_T_COMMAND:-fd --type f --hidden --follow --exclude .git}"
  FZF_ALT_C_COMMAND="${FZF_ALT_C_COMMAND:-fd --type d --hidden --follow --exclude .git}"
fi
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---height 40%}"
FZF_TMUX_HEIGHT="${FZF_TMUX_HEIGHT:-40%}"

# Simple aliases
alias ..="cd .."
# grep -> rg wrapper: see personal.d/grep-ripgrep.zsh
alias egrep="egrep --color=auto"
alias tidy="json_xs -f json -t json-pretty"
alias lg="lazygit"
alias ping="/sbin/ping"
alias spark='ssh -t -L 5902:localhost:5902 gordolio@192.168.0.159 "tmux -CC new -A -s main"'
alias spark-ssh="$HOME/src/shell-config/bin/spark-ssh"
if __tool_check_cmd "screenfetch" screenfetch tool; then
  alias screenfetch="command screenfetch -D 'Mac OS X'"
fi

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
export GPG_TTY=$TTY

# claude code statusline dependencies
__tool_check_cmd "claude" claude claude
__tool_check_cmd "jq" jq claude
__tool_check_cmd "curl" curl claude
__tool_check_cmd "mitmproxy" mitmdump claude
__tool_check_path "claude-statusline" "$HOME/src/shell-config/claude/statusline-command.sh" claude file

# 1Password shell plugin: `op plugin init claude-code` writes a `claude()`
# shim into ~/.config/op/plugins.sh that runs `op plugin run -- claude ...`.
# We don't source that file — detect and route ourselves instead.
if [[ -f "$HOME/.config/op/plugins.sh" ]] && command grep -q 'claude()' "$HOME/.config/op/plugins.sh"; then
  __tool_record "claude-op-plugin" claude configured "$HOME/.config/op/plugins.sh" "$HOME/.config/op/plugins.sh"
  function claude {
    op plugin run -- claude "$@"
  }
else
  __tool_record "claude-op-plugin" claude missing "run: op plugin init claude-code" "$HOME/.config/op/plugins.sh"
fi
