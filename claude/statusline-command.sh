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

# Simple left-to-right layout with consistent bar separators
echo "${PURPLE}${username}${RESET} ${BAR} ${PINK}${path_basename}${RESET}${git_info} ${BAR} ${CYAN}${current_time}${RESET}${battery}"