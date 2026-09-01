#!/bin/sh
# gpg-agent pinentry dispatcher.
#
# WebStorm generates this file at ~/.gnupg/pinentry-ide.sh and points
# gpg-agent.conf at it. Tracked here and symlinked back so an IDE rewrite shows up
# as a git diff (or as a broken symlink in ls-tools) instead of silently reverting
# the fallback below. WebStorm has already done this once, on 2026-08-31, writing
# straight through the symlink -- so if signing suddenly fails from a non-interactive
# shell, check `git status` here first.
#
# The two IJ_* branches are WebStorm's own and are left as generated. Only the
# fallback differs: upstream ends at pinentry-curses, which needs a controlling tty
# and therefore fails for any non-interactive caller (agent shells, scripts, hooks)
# with "No pinentry" or "Inappropriate ioctl for device". pinentry-mac draws a GUI
# prompt and works from any process.

if [ -n "$PINENTRY_USER_DATA" ]; then
  case "$PINENTRY_USER_DATA" in
    IJ_PINENTRY=*)
      "$HOME/Applications/WebStorm.app/Contents/jbr/Contents/Home/bin/java" -cp "$HOME/Applications/WebStorm.app/Contents/plugins/vcs-git/lib/git4idea-rt.jar:$HOME/Applications/WebStorm.app/Contents/lib/externalProcess-rt.jar" git4idea.gpg.PinentryApp
      exit $?
    ;;
    IJ_PINENTRY_ENTRYPOINT=*)
      EXTERNAL_CLI_ENTRYPOINT=${PINENTRY_USER_DATA#IJ_PINENTRY_ENTRYPOINT=}
      EXTERNAL_CLI_ENTRYPOINT=${EXTERNAL_CLI_ENTRYPOINT%%:*}
      $EXTERNAL_CLI_ENTRYPOINT
      exit $?
    ;;
  esac
fi

if [ -x /opt/homebrew/bin/pinentry-mac ]; then
  exec /opt/homebrew/bin/pinentry-mac "$@"
fi
exec /opt/homebrew/opt/pinentry/bin/pinentry "$@"
