# Shell Config

## Commit Rules

- **Never** add `Co-Authored-By` trailers to git commits.

## Claude Code Statusline (`claude/`)

The `claude/` directory contains the statusline script for Claude Code.

- `statusline-command.sh` — Claude Code statusline script that displays the vim-mode chip, model, user, path, git info, time, version, and context/usage dot bars. Uses data from Claude Code's statusline JSON input (no external API calls needed).
