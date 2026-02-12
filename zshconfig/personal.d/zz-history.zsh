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

# History search chain: atuin > fzf
if __tool_check_cmd "atuin" atuin history-search; then
  eval "$(atuin init zsh)"
else
  # fzf binding remains active from fzf init in zshrc
  __tool_record "fzf-history" "history-search" loaded "fzf (fallback)" ""
fi
