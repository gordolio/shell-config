shell-config
============

This is my default shell config. It includes config for Zsh (Zinit), Oh My Posh, Vim, and Git.
I mostly use macOS, but I try to keep it cross platform for Linux and Cygwin.

## Quick Install

Requires Homebrew. Clones to `~/src/shell-config` and symlinks everything into place.

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/gordolio/shell-config/main/install.sh)
```

## Spark SSH profiles

The iTerm2 `spark` and `spark vnc` profiles run `bin/spark-ssh` directly.
It starts or reuses a Homebrew OpenSSH agent and loads `~/.ssh/id_ed25519` and
`~/.ssh/id_sudo_yubikey` only when they are missing from the agent. Both keys
are forwarded to Spark; the ordinary key is selected for SSH login. The VNC
profile also forwards local port 5902.

The agent survives closing a profile, so reopening it does not reload the keys.
After a reboot or an agent restart, the next profile launch loads them again;
encrypted keys may ask for their passphrase. The YubiKey must be connected
when Spark asks it to sign for sudo. To inspect the local agent, run
`spark-ssh --agent-only` (a zsh alias for the script). Existing SSH connections
must be reopened to use this agent.

If iTerm2 is already running when these preferences change, reload preferences
from the configured custom folder or restart iTerm2 before opening a Spark profile.
