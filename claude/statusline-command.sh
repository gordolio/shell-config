#!/bin/bash

# Read JSON input from Claude Code
input=$(cat)
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model_name=$(echo "$input" | jq -r '.model.display_name // .model.id')

# Get username
username=$(whoami)

# Get basename for shorter display
path_basename=$(basename "$current_dir")

# Colors using $'...' syntax for proper escape interpretation
# Bar color: #6c71c4 (solarized violet) = 256-color 62
BAR=$'\e[38;5;62m│\e[0m'
PURPLE=$'\e[95m'
PINK=$'\e[91m'
YELLOW=$'\e[93m'
CYAN=$'\e[96m'
GREEN=$'\e[92m'
RESET=$'\e[0m'

# Get git info if we're in a git repo
git_info=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        working_changes=""
        staging_changes=""

        if [ -n "$(git status --porcelain 2>/dev/null | grep '^[^?]')" ]; then
            working_changes=" ●"
        fi

        if [ -n "$(git status --porcelain 2>/dev/null | grep '^[AMDRC]')" ]; then
            staging_changes=" +"
        fi

        git_info=" ${BAR} ${YELLOW}⎇ ${branch}${working_changes}${staging_changes}${RESET}"
    fi
fi

# Get current time (12-hour with AM/PM)
current_time=$(date '+%I:%M %p')

# Get battery level (macOS)
battery=""
if command -v pmset &> /dev/null; then
    battery_pct=$(pmset -g batt | grep -Eo '[0-9]+%' | head -1)
    if [ -n "$battery_pct" ]; then
        battery=" ${BAR} ${GREEN}🔋 ${battery_pct}${RESET}"
    fi
fi

# Get plan usage (5-hour session %) with 5-minute cache
# If the API returns a 4xx, we write a flag file and stop trying.
# To re-enable: rm /tmp/claude-usage-disabled
USAGE_CACHE="/tmp/claude-usage-cache.json"
USAGE_DISABLED="/tmp/claude-usage-disabled"
CACHE_MAX_AGE=300
usage=""
if [ ! -f "$USAGE_DISABLED" ]; then
    now=$(date +%s)
    cache_age=$((now + CACHE_MAX_AGE)) # default: force refresh
    if [ -f "$USAGE_CACHE" ]; then
        cache_mtime=$(stat -f %m "$USAGE_CACHE" 2>/dev/null || echo 0)
        cache_age=$((now - cache_mtime))
    fi
    if [ "$cache_age" -ge "$CACHE_MAX_AGE" ]; then
        token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty')
        if [ -n "$token" ]; then
            # Use oauth beta flag captured from Claude Code, fall back to hardcoded
            BETA_HEADER=$(tr ',' '\n' < "$HOME/.claw-header-detect/anthropic-beta" 2>/dev/null | grep '^oauth-' || echo "oauth-2025-04-20")
            http_code=$(curl -s --max-time 5 -o /tmp/claude-usage-response.json -w '%{http_code}' \
                -H "Authorization: Bearer $token" \
                -H "anthropic-beta: $BETA_HEADER" \
                "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
            if [ "$http_code" -ge 400 ] && [ "$http_code" -lt 500 ] 2>/dev/null; then
                echo "Disabled at $(date). HTTP $http_code. rm this file to retry." > "$USAGE_DISABLED"
                rm -f /tmp/claude-usage-response.json
            elif jq -e '.five_hour' /tmp/claude-usage-response.json > /dev/null 2>&1; then
                mv /tmp/claude-usage-response.json "$USAGE_CACHE"
            else
                rm -f /tmp/claude-usage-response.json
            fi
        fi
    fi
    if [ -f "$USAGE_CACHE" ]; then
        five_hour=$(jq -r '.five_hour.utilization // empty' "$USAGE_CACHE" 2>/dev/null)
        if [ -n "$five_hour" ]; then
            WARM_AMBER=$'\e[38;2;234;179;80m'
            usage=" ${BAR} ${WARM_AMBER}⚡ ${five_hour%.*}%${RESET}"
        fi
    fi
fi

# Version display and header change detection
HEADER_DIR="$HOME/.claw-header-detect"
header_info=""
claude_version=$(readlink "$HOME/.local/bin/claude" 2>/dev/null | xargs basename 2>/dev/null || true)
if [ -n "$claude_version" ]; then
    DIM_LAVENDER=$'\e[38;2;147;130;186m'
    version_display=" ${BAR} ${DIM_LAVENDER}v${claude_version}${RESET}"
    last_version=""
    [ -f "$HEADER_DIR/last-version" ] && last_version=$(cat "$HEADER_DIR/last-version" 2>/dev/null)
    if [ "$claude_version" != "$last_version" ]; then
        version_display=" ${BAR} ${YELLOW}v${claude_version} ↑${RESET}"
        # Version changed — spawn capture in background (if not already running)
        CAPTURE_SCRIPT="$(dirname "$0")/capture-claude-headers.sh"
        if [ -x "$CAPTURE_SCRIPT" ] && [ ! -d "$HEADER_DIR/.capture.lock" ]; then
            if ! command -v mitmdump &>/dev/null; then
                header_info=" ${YELLOW}(missing mitmdump)${RESET}"
            else
                nohup "$CAPTURE_SCRIPT" "$claude_version" > "$HEADER_DIR/capture.log" 2>&1 &
            fi
        fi
    fi
    # Show notice if headers changed or beta header is missing
    if [ -f "$HEADER_DIR/beta-missing" ]; then
        header_info=" ${BAR} ${PINK}⚠ anthropic-beta gone${RESET}"
    elif [ -f "$HEADER_DIR/changed-notice" ]; then
        header_info=" ${BAR} ${YELLOW}⚡ headers changed${RESET}"
    fi
fi

# Simple left-to-right layout with consistent bar separators
echo "${PURPLE}${username}${RESET} ${BAR} ${PINK}${path_basename}${RESET}${git_info} ${BAR} ${CYAN}${current_time}${RESET}${battery}${usage}${version_display}${header_info}"