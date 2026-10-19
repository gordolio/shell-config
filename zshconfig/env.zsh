# =============================================================================
# Everyone layer: humans and agents
# =============================================================================
#
# Sourced by zprofile (login shells; Codex's `zsh -lc` reads only this path) and
# by zshrc (interactive shells, plus Claude Code's snapshot shell, which is a
# non-interactive login shell that sources ~/.zshrc and keeps what it defines).
#
# Belongs here: PATH entries, exports, and wrappers that decide whether a command
# works or is safe (npm/yarn token placeholders, the Prisma guard). Anything that
# only changes output or swaps the tool goes in personal.d/, which only
# interactive shells load.
#
# Keep this cheap: no `eval "$(tool init)"`, no network, no prompts.

# Login + interactive shells source this twice (zprofile, then zshrc). The guard
# is a plain shell variable, so child shells (which inherit PATH but not
# functions) still load it.
[[ -n $__shell_config_env_loaded ]] && return 0
typeset -g __shell_config_env_loaded=1

# Login shells get /etc/paths and /etc/paths.d from path_helper (/etc/zprofile).
# iTerm2 starts profile commands as non-login shells with only the system PATH,
# so run it here for those too, as fish did on its own. The env.d prepends below
# move back ahead of the system entries it puts first.
if [[ ! -o login && -x /usr/libexec/path_helper ]]; then
  eval "$(/usr/libexec/path_helper -s)"
fi

__env_d="${${(%):-%x}:A:h}/env.d"

if [[ -d "$__env_d" ]]; then
  for __f in "$__env_d"/*.zsh(N); do
    source "$__f"
  done
fi

unset __env_d __f
