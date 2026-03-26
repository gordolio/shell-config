#!/bin/bash

# Read JSON input from Claude Code
input=$(cat)
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model_name=$(echo "$input" | jq -r '.model.display_name // .model.id' | sed 's/ ([^)]*context)//')
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

# Get current time (12-hour with am/pm, no space)
current_time=$(date '+%I:%M%p' | tr '[:upper:]' '[:lower:]')

# Context window % — shown on line 1 as plain number (no dots)
ctx_display=""
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
    ctx_int=${used_pct%.*}
    ctx_col=$(pct_color "$ctx_int")
    ctx_display=" ${BAR} ${ctx_col}ctx ${ctx_int}%${RESET}"
fi

# Get plan usage (5-hour + weekly) from Claude Code's native JSON input
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
five_reset_ts=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)
weekly_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)
weekly_reset_ts=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty' 2>/dev/null)

# Format seconds remaining → "Xhr Ymin" / "Ymin" / "Zs"
format_until() {
    local reset_ts=$1
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
    local reset_ts=$1
    date -r "$reset_ts" "+%a %l:%M%p" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/^ //'
}

# Build usage dot-bar lines from native input
current_line=""
weekly_line=""

if [ -n "$five_pct" ]; then
    five_int=${five_pct%.*}
    five_col=$(pct_color "$five_int")
    five_dots=$(make_dots "$five_int" "$five_col")
    five_until=""
    [ -n "$five_reset_ts" ] && { until=$(format_until "$five_reset_ts"); [ -n "$until" ] && five_until=" ${DIM}↺ ${until}${RESET}"; }
    current_line="${DIM_LAVENDER}current${RESET} ${five_dots} ${five_col}${five_int}%${RESET}${five_until}"
fi

if [ -n "$weekly_pct" ]; then
    weekly_int=${weekly_pct%.*}
    weekly_col=$(pct_color "$weekly_int")
    weekly_dots=$(make_dots "$weekly_int" "$weekly_col")
    weekly_when=""
    [ -n "$weekly_reset_ts" ] && { when=$(format_reset_date "$weekly_reset_ts"); [ -n "$when" ] && weekly_when=" ${DIM}↺ ${when}${RESET}"; }
    weekly_line="${DIM_LAVENDER}weekly ${RESET} ${weekly_dots} ${weekly_col}${weekly_int}%${RESET}${weekly_when}"
fi

# Version display
claude_version=$(echo "$input" | jq -r '.version // empty' 2>/dev/null)
if [ -z "$claude_version" ]; then
    claude_version=$(readlink "$HOME/.local/bin/claude" 2>/dev/null | xargs basename 2>/dev/null || true)
fi
version_display=""
if [ -n "$claude_version" ]; then
    version_display=" ${BAR} ${DIM_LAVENDER}v${claude_version}${RESET}"
fi

# Model display: bold cyan for Opus, plain cyan otherwise
if echo "$model_id" | grep -qi "opus"; then
    model_display="${BOLD}${CYAN}${model_name}${RESET}"
else
    model_display="${CYAN}${model_name}${RESET}"
fi

# ── LINE 1 ────────────────────────────────────────────────────────────────────
echo "${model_display} ${BAR} ${PURPLE}${username}${RESET} ${BAR} ${PINK}${path_basename}${RESET}${git_info} ${BAR} ${CYAN}${current_time}${RESET}${ctx_display}${version_display}"

# ── LINE 2: current (five-hour) dot bar ───────────────────────────────────────
if [ -n "$current_line" ]; then echo "$current_line"; fi

# ── LINE 3: weekly dot bar ────────────────────────────────────────────────────
if [ -n "$weekly_line" ]; then echo "$weekly_line"; fi
