#!/bin/sh
if [ -n "$PINENTRY_USER_DATA" ]; then
  case "$PINENTRY_USER_DATA" in
    IJ_PINENTRY=*)
      "/Users/gordon/Applications/WebStorm.app/Contents/jbr/Contents/Home/bin/java" -cp "/Users/gordon/Applications/WebStorm.app/Contents/plugins/vcs-git/lib/git4idea-rt.jar:/Users/gordon/Applications/WebStorm.app/Contents/lib/externalProcess-rt.jar" git4idea.gpg.PinentryApp
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
exec /opt/homebrew/bin/pinentry-mac "$@"