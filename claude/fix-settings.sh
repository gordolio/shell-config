#!/usr/bin/env bash
# Idempotently register this repo's Claude Code hooks and statusline, plus
# iTerm2's Claude Code integration hook, in ~/.claude/settings.json.
#
# settings.json is not tracked or symlinked: Claude Code, /config, plugin
# toggles and iTerm2's onboarding wizard all write to it, so a tracked copy
# would diff constantly. This merges in only the entries listed below and
# leaves every other key alone. An entry counts as present when its event
# already has a hook with the same command, whatever its matcher/timeout, so
# hand-tuned entries are never rewritten. Safe to re-run.
#
# Retired hooks (retired_hooks below) are the one exception: their settings
# entries are removed and their dangling ~/.claude/hooks symlinks deleted, so
# a hook dropped from this repo does not keep firing, and failing, on every
# machine that registered it.
#
# iTerm2 entries: Settings > General > AI > Claude Code integration installs
# the cc-status hook on the events below and symlinks ~/.config/iterm2/cc-status
# into the app bundle. The rest of that integration (Python API, Session Status
# toolbelt tool, Claude Code workgroup) lives in the tracked iTerm2 plist. If
# a newer iTerm2 hooks more events, re-run its wizard once and copy the new
# events into iterm_events.
#
# Usage: fix-settings.sh           apply missing entries
#        fix-settings.sh --check   exit 1 if anything is missing; no changes

set -u

shell_config="${SHELL_CONFIG:-$HOME/src/shell-config}"
settings="$HOME/.claude/settings.json"
cc_status_link="$HOME/.config/iterm2/cc-status"
cc_status_target="/Applications/iTerm.app/Contents/Resources/utilities/cc-status"

check_only=0
[[ "${1:-}" == "--check" ]] && check_only=1

iterm_events=(Notification PermissionRequest PostToolUse PreToolUse SessionEnd
              SessionStart Stop StopFailure SubagentStop UserPromptSubmit)

# One entry per line: event<TAB>matcher<TAB>timeout<TAB>command (empty = unset).
wanted=$(
  printf 'PreToolUse\tBash\t\t%s\n' "$HOME/.claude/hooks/gh-guard.py"
  for event in "${iterm_events[@]}"; do
    printf '%s\t\t\t%s\n' "$event" "$cc_status_link"
  done
)
retired_hooks=("$HOME/.claude/hooks/gh-allowlist.py"
               "$HOME/.claude/hooks/confirm-git-commit.sh"
               "$HOME/.claude/hooks/git-push-allowlist.py")
statusline_cmd="$shell_config/claude/statusline-command.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "fix-settings: jq not found, skipping" >&2
  exit 0
fi

current='{}'
if [[ -f "$settings" ]]; then
  if ! current=$(jq -e 'if type == "object" then . else error("not an object") end' "$settings" 2>/dev/null); then
    echo "❌ $settings is not a valid JSON object, leaving it alone" >&2
    exit 1
  fi
fi

# Emits {settings, added: [labels]}.
result=$(jq --arg wanted "$wanted" --arg statusline "$statusline_cmd" \
  --args '
  $ARGS.positional as $retired
  | ($wanted | split("\n") | map(select(length > 0) | split("\t")
    | {event: .[0], matcher: .[1], timeout: .[2], command: .[3]})) as $entries
  | reduce $entries[] as $e ({settings: ., added: []};
      if any(.settings.hooks[$e.event][]?.hooks[]?; .command == $e.command) then .
      else
        .settings.hooks[$e.event] += [
          (if $e.matcher != "" then {matcher: $e.matcher} else {} end)
          + {hooks: [{type: "command", command: $e.command}
                     + (if $e.timeout != "" then {timeout: ($e.timeout | tonumber)} else {} end)]}]
        | .added += ["added \($e.event): \($e.command | split("/") | last)"]
      end)
  | if .settings.statusLine == null then
      .settings.statusLine = {type: "command", command: $statusline}
      | .added += ["added statusLine: \($statusline | split("/") | last)"]
    else . end
  | reduce $retired[] as $r (.;
      if any(.settings.hooks[]?[]?.hooks[]?; .command == $r) then
        .settings.hooks |= (map_values(
            map(.hooks |= map(select(.command != $r))) | map(select(.hooks | length > 0)))
          | with_entries(select(.value | length > 0)))
        | .added += ["removed retired hook: \($r | split("/") | last)"]
      else . end)
' "${retired_hooks[@]}" <<<"$current") || { echo "❌ fix-settings: jq merge failed" >&2; exit 1; }

stale_links=()
for hook in "${retired_hooks[@]}"; do
  [[ -L "$hook" ]] && stale_links+=("$hook")
done

link_ok=0
[[ -L "$cc_status_link" && "$(readlink "$cc_status_link")" == "$cc_status_target" ]] && link_ok=1

if (( check_only )); then
  missing=$(jq -r '.added[]' <<<"$result")
  (( link_ok )) || missing+=$'\n'"symlink: $cc_status_link"
  for hook in ${stale_links[@]+"${stale_links[@]}"}; do
    missing+=$'\n'"stale symlink: ${hook/#$HOME/~}"
  done
  [[ -z "${missing//$'\n'/}" ]] && exit 0
  printf '%s\n' "$missing" | sed '/^$/d'
  exit 1
fi

display_settings="${settings/#$HOME/~}"

if (( link_ok )); then
  echo "✅ ${cc_status_link/#$HOME/~} -> iTerm2 cc-status (ok)"
elif [[ ! -x "$cc_status_target" ]]; then
  echo "⚠️  $cc_status_target not found (iTerm2 too old or not installed?), skipping symlink" >&2
else
  mkdir -p "$(dirname "$cc_status_link")"
  ln -sfn "$cc_status_target" "$cc_status_link"
  echo "🔧 ${cc_status_link/#$HOME/~} -> iTerm2 cc-status (created)"
fi

for hook in ${stale_links[@]+"${stale_links[@]}"}; do
  rm -f "$hook"
  echo "🔧 ${hook/#$HOME/~}: removed retired hook symlink"
done

if [[ $(jq '.added | length' <<<"$result") -eq 0 ]]; then
  echo "✅ $display_settings has all Claude Code hooks and statusline (ok)"
  exit 0
fi

mkdir -p "$(dirname "$settings")"
tmp=$(mktemp "$settings.XXXXXX") || exit 1
if jq '.settings' <<<"$result" >"$tmp"; then
  # cat rather than mv so an existing file keeps its inode and permissions.
  cat "$tmp" >"$settings"
  rm -f "$tmp"
else
  rm -f "$tmp"
  echo "❌ fix-settings: failed to write $settings" >&2
  exit 1
fi

jq -r '.added[]' <<<"$result" | while IFS= read -r label; do
  echo "🔧 $display_settings: $label"
done
