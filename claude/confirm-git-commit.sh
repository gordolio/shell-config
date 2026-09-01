#!/usr/bin/env bash
# PreToolUse(Bash) gate for commit-finalizing git operations.
#
# Opens the staged diff in Beyond Compare and holds the tool call behind a native
# approval dialog. Approving here also satisfies the normal Bash permission prompt,
# so it is one gesture rather than two.
#
# Symlinked to ~/.claude/hooks/confirm-git-commit.sh by `ls-tools --fix`, and
# registered under hooks.PreToolUse[matcher=Bash] in ~/.claude/settings.json with a
# long timeout so the dialog is not killed while the diff is still being read.

set -uo pipefail

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')
[[ -n $cmd ]] || exit 0

# Cheap check first. Anything that is not commit-finalizing passes straight through
# with no dialog and no diff. Deliberately permissive: an extra dialog is a nuisance,
# a missed commit is the failure this exists to prevent.
printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_.-])git([[:space:]]|$)' || exit 0
printf '%s' "$cmd" | grep -Eq '[[:space:]](commit|--continue)([[:space:]]|$)' || exit 0

decision() {
  jq -nc --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: $d,
        permissionDecisionReason: $r}}'
}

cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty')
[[ -n $cwd ]] || cwd=$PWD
repo=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || repo=$cwd
branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null) || branch='(unknown)'

if git -C "$repo" diff --cached --quiet 2>/dev/null; then
  summary='No staged changes.'
else
  summary=$(git -C "$repo" diff --cached --shortstat 2>/dev/null | sed 's/^[[:space:]]*//')
  if command -v bcompare >/dev/null 2>&1; then
    # --dir-diff opens the whole changeset as one folder comparison rather than
    # blocking per file. Backgrounded so the dialog appears immediately. Uses the
    # configured diff.tool rather than forcing one.
    nohup git -C "$repo" difftool --cached --dir-diff --no-prompt >/dev/null 2>&1 &
    disown 2>/dev/null
    summary+=$'\n'"Opened in Beyond Compare."
  else
    plain=$(mktemp -t staged-diff-XXXXXX)
    mv "$plain" "$plain.diff"
    git -C "$repo" diff --cached >"$plain.diff" 2>/dev/null
    nohup open -t "$plain.diff" >/dev/null 2>&1 &
    disown 2>/dev/null
    summary+=$'\n'"Beyond Compare not found. Opened plain diff."
  fi
fi

osascript \
  -e 'on run {theCmd, theRepo, theBranch, theSummary}' \
  -e 'display dialog "Branch: " & theBranch & return & "Repo: " & theRepo & return & return & theSummary & return & return & "Command:" & return & theCmd with title "Approve commit?" buttons {"Cancel", "Approve"} default button "Approve" cancel button "Cancel" with icon caution' \
  -e 'end run' \
  -- "$cmd" "$repo" "$branch" "$summary" >/dev/null 2>&1
approved=$?

if [[ $approved -eq 0 ]]; then
  decision allow 'Approved by the User against the staged diff.'
else
  decision deny 'The User declined this commit at the approval dialog. Do not retry it or reword the message; ask what they want changed first.'
fi
