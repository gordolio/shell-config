#!/bin/bash

# Read JSON input from Claude Code
input=$(cat)
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model_name=$(echo "$input" | jq -r '.model.display_name // .model.id')
model_id=$(echo "$input" | jq -r '.model.id // ""')

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
BOLD=$'\e[1m'
DIM=$'\e[2m'
WARM_AMBER=$'\e[38;2;234;179;80m'
ORANGE=$'\e[38;5;208m'
RED=$'\e[38;5;196m'
DIM_LAVENDER=$'\e[38;2;147;130;186m'

# Dot progress bar: 10 spaced dots colored by pct
make_dots() {
    local pct=$1
    local color=$2
    local filled=$(( pct * 10 / 100 ))
    local empty=$(( 10 - filled ))
    local bar=""
    for (( i=0; i<filled; i++ )); do bar="${bar}${color}●${RESET} "; done
    for (( i=0; i<empty;  i++ )); do bar="${bar}${DIM}○${RESET} "; done
    echo "$bar"
}

# Color based on percentage
pct_color() {
    local pct=$1
    if   [ "$pct" -lt 50 ]; then echo "$GREEN"
    elif [ "$pct" -lt 75 ]; then echo "$WARM_AMBER"
    elif [ "$pct" -lt 90 ]; then echo "$ORANGE"
    else                          echo "$RED"
    fi
}

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

# Context window % — shown on line 1 as plain number (no dots)
ctx_display=""
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
    ctx_int=${used_pct%.*}
    ctx_col=$(pct_color "$ctx_int")
    ctx_display=" ${BAR} ${ctx_col}ctx ${ctx_int}%${RESET}"
fi

# Get plan usage (5-hour + weekly) with 5-minute cache
# To re-enable after 4xx: rm /tmp/claude-usage-disabled
USAGE_CACHE="/tmp/claude-usage-cache.json"
USAGE_DISABLED="/tmp/claude-usage-disabled"
CACHE_MAX_AGE=300
if [ ! -f "$USAGE_DISABLED" ]; then
    now=$(date +%s)
    cache_age=$((now + CACHE_MAX_AGE))  # default: force refresh
    if [ -f "$USAGE_CACHE" ]; then
        cache_mtime=$(stat -f %m "$USAGE_CACHE" 2>/dev/null || echo 0)
        cache_age=$((now - cache_mtime))
    fi
    if [ "$cache_age" -ge "$CACHE_MAX_AGE" ]; then
        # NOTE: security -w truncates at ~4096 bytes, breaking jq parsing
        # when MCP OAuth tokens bloat the credential blob. Use grep instead.
        token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | grep -o '"accessToken":"[^"]*"' | head -1 | sed 's/"accessToken":"//; s/"$//')
        if [ -n "$token" ]; then
            BETA_HEADER=$(tr ',' '\n' < "$HOME/.claw-header-detect/anthropic-beta" 2>/dev/null | grep '^oauth-' || echo "oauth-2025-04-20")
            UA_HEADER=$(cat "$HOME/.claw-header-detect/user-agent" 2>/dev/null || echo "claude-cli/unknown (external, cli)")
            http_code=$(curl -s --max-time 5 -o /tmp/claude-usage-response.json -w '%{http_code}' \
                -H "Authorization: Bearer $token" \
                -H "anthropic-beta: $BETA_HEADER" \
                -H "User-Agent: $UA_HEADER" \
                "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
            if [ "$http_code" = "429" ] 2>/dev/null; then
                # Rate limited — transient, just skip this refresh
                rm -f /tmp/claude-usage-response.json
            elif [ "$http_code" -ge 400 ] && [ "$http_code" -lt 500 ] 2>/dev/null; then
                echo "Disabled at $(date). HTTP $http_code. rm this file to retry." > "$USAGE_DISABLED"
                rm -f /tmp/claude-usage-response.json
            elif jq -e '.five_hour' /tmp/claude-usage-response.json > /dev/null 2>&1; then
                mv /tmp/claude-usage-response.json "$USAGE_CACHE"
            else
                rm -f /tmp/claude-usage-response.json
            fi
        fi
    fi
fi

# Format seconds remaining → "Xhr Ymin" / "Ymin" / "Zs"
format_until() {
    local reset_at=${1%%.*}Z  # strip fractional seconds + tz offset → "...T%H:%M:%SZ"
    local reset_ts
    reset_ts=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$reset_at" "+%s" 2>/dev/null) || return
    local diff=$(( reset_ts - $(date +%s) ))
    [ "$diff" -le 0 ] && return
    local hrs=$(( diff / 3600 ))
    local mins=$(( (diff % 3600) / 60 ))
    if   [ "$hrs"  -gt 0 ]; then echo "${hrs}hr ${mins}min"
    elif [ "$mins" -gt 0 ]; then echo "${mins}min"
    else                          echo "${diff}s"
    fi
}

# Format reset timestamp → "Mon 3:00pm"
format_reset_date() {
    local reset_at=${1%%.*}Z  # strip fractional seconds + tz offset → "...T%H:%M:%SZ"
    local reset_ts
    reset_ts=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$reset_at" "+%s" 2>/dev/null) || return
    date -r "$reset_ts" "+%a %l:%M%p" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/^ //'
}

# Build usage dot-bar lines from cache
current_line=""
weekly_line=""
if [ -f "$USAGE_CACHE" ]; then
    # Current (five-hour window)
    five_pct=$(jq -r '.five_hour.utilization // empty' "$USAGE_CACHE" 2>/dev/null)
    if [ -n "$five_pct" ]; then
        five_int=${five_pct%.*}
        five_col=$(pct_color "$five_int")
        five_dots=$(make_dots "$five_int" "$five_col")
        five_reset=$(jq -r '.five_hour.resets_at // empty' "$USAGE_CACHE" 2>/dev/null)
        five_until=""
        [ -n "$five_reset" ] && { until=$(format_until "$five_reset"); [ -n "$until" ] && five_until=" ${DIM}↺ ${until}${RESET}"; }
        current_line="${DIM_LAVENDER}current${RESET} ${five_dots} ${five_col}${five_int}%${RESET}${five_until}"
    fi

    # Weekly
    weekly_pct=$(jq -r '.seven_day.utilization // empty' "$USAGE_CACHE" 2>/dev/null)
    if [ -n "$weekly_pct" ]; then
        weekly_int=${weekly_pct%.*}
        weekly_col=$(pct_color "$weekly_int")
        weekly_dots=$(make_dots "$weekly_int" "$weekly_col")
        weekly_reset=$(jq -r '.seven_day.resets_at // empty' "$USAGE_CACHE" 2>/dev/null)
        weekly_when=""
        [ -n "$weekly_reset" ] && { when=$(format_reset_date "$weekly_reset"); [ -n "$when" ] && weekly_when=" ${DIM}↺ ${when}${RESET}"; }
        weekly_line="${DIM_LAVENDER}weekly ${RESET} ${weekly_dots} ${weekly_col}${weekly_int}%${RESET}${weekly_when}"
    fi
fi

# Version display and header change detection
HEADER_DIR="$HOME/.claw-header-detect"
header_info=""
claude_version=$(readlink "$HOME/.local/bin/claude" 2>/dev/null | xargs basename 2>/dev/null || true)
version_display=""
if [ -n "$claude_version" ]; then
    version_display=" ${BAR} ${DIM_LAVENDER}v${claude_version}${RESET}"
    last_version=""
    [ -f "$HEADER_DIR/last-version" ] && last_version=$(cat "$HEADER_DIR/last-version" 2>/dev/null)
    if [ "$claude_version" != "$last_version" ]; then
        version_display=" ${BAR} ${YELLOW}v${claude_version} ↑${RESET}"
        # Version changed — spawn capture in background (if not already running)
        CAPTURE_SCRIPT="$HOME/src/shell-config/claude/capture-claude-headers.sh"
        if [ -x "$CAPTURE_SCRIPT" ] && [ ! -d "$HEADER_DIR/capture.lock" ]; then
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

# Model display: bold cyan for Opus, plain cyan otherwise
if echo "$model_id" | grep -qi "opus"; then
    model_display="${BOLD}${CYAN}${model_name}${RESET}"
else
    model_display="${CYAN}${model_name}${RESET}"
fi

# ── LINE 1 ────────────────────────────────────────────────────────────────────
echo "${model_display} ${BAR} ${PURPLE}${username}${RESET} ${BAR} ${PINK}${path_basename}${RESET}${git_info} ${BAR} ${CYAN}${current_time}${RESET}${ctx_display}${version_display}${header_info}"

# ── LINE 2: current (five-hour) dot bar ───────────────────────────────────────
if [ -n "$current_line" ]; then echo "$current_line"; fi

# ── LINE 3: weekly dot bar ────────────────────────────────────────────────────
if [ -n "$weekly_line" ]; then echo "$weekly_line"; fi
