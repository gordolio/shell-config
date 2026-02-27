#!/bin/bash
# Git clean filter: strips sensitive values from iTerm2 plist before staging.
# Used via .gitattributes + git config filter.iterm2-sanitize.clean
#
# Replaces the value of known sensitive keys with an empty string.

sed -E '
  # Match a <key> line for a sensitive key, then blank the next <string> value
  /\<key\>NoSyncOpenAIAPIKey\<\/key\>/ {
    N
    s|(<string>)[^<]*(</string>)|\1\2|
  }
'
