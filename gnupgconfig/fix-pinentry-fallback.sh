#!/usr/bin/env bash
# Idempotently set the pinentry fallback that WebStorm reads out of
# ~/.gnupg/gpg-agent.conf.bak whenever it regenerates ~/.gnupg/pinentry-ide.sh
# (git4idea.commit.signing.GpgAgentConfigurator.updateExistingPinentryLauncher,
# which always rewrites the launcher once the embedded-pinentry feature has
# configured gpg-agent.conf, and prefers this backup file's pinentry-program
# over a live `gpgconf --list-components` lookup).
#
# Without this file, WebStorm falls back to whatever gpgconf reports as the
# system default pinentry -- pinentry-curses on these Macs, which needs a
# controlling tty and fails outright for any non-interactive caller (agent
# shells, scripts, hooks). pinentry-mac works from any process.
#
# Only touches the pinentry-program key; leaves any other lines in the
# backup file alone. Safe to re-run.

set -u

pinentry_mac="/opt/homebrew/bin/pinentry-mac"
bak_file="$HOME/.gnupg/gpg-agent.conf.bak"

if [[ ! -x "$pinentry_mac" ]]; then
  echo "fix-pinentry-fallback: $pinentry_mac not found, skipping" >&2
  exit 0
fi

mkdir -p "$HOME/.gnupg"
[[ -f "$bak_file" ]] || : > "$bak_file"

target_line="pinentry-program $pinentry_mac"

if grep -qx "$target_line" "$bak_file" 2>/dev/null; then
  echo "✅ $bak_file already has pinentry-program = $pinentry_mac"
elif grep -q '^pinentry-program[[:space:]]' "$bak_file" 2>/dev/null; then
  perl -i -pe "s{^pinentry-program\s.*\$}{$target_line}" "$bak_file"
  echo "🔧 updated $bak_file: pinentry-program = $pinentry_mac"
else
  printf '%s\n' "$target_line" >> "$bak_file"
  echo "🔧 $bak_file: added pinentry-program = $pinentry_mac"
fi
