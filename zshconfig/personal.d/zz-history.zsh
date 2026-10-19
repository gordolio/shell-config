# History configuration and search chain: atuin > fzf
# Loads after other personal configs (zz- prefix) so atuin keybindings override vi-mode rebinds

# History settings
HISTSIZE=10000000
SAVEHIST=10000000
if (( ! EUID )); then
  HISTFILE=~/.history_root
else
  HISTFILE=~/.history
fi

setopt SHARE_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS

# fzf key bindings and fuzzy completion: Ctrl-T files, Alt-C cd, Ctrl-R history.
# Sourced before atuin so atuin's Ctrl-R wins when it's installed.
if __tool_check_cmd "fzf" fzf search-tools; then
  __cached_eval fzf fzf fzf --zsh
  # fzf also takes Ctrl-R in vi normal mode, which is redo there; atuin leaves it alone.
  bindkey -M vicmd '^R' redo
fi

# History search chain: atuin > fzf
if __tool_check_cmd "atuin" atuin history-search; then
  eval "$(atuin init zsh)"
else
  # fzf's Ctrl-R binding (sourced above) stays active
  __tool_record "fzf-history" "history-search" loaded "fzf (fallback)" ""
fi
