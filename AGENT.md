# Shell Config

## Claude Code Header Capture (`claude/`)

The `claude/` directory tracks HTTP headers sent by Claude Code so we can query the Anthropic usage API (`/api/oauth/usage`) for remaining session quota.

- `capture-claude-headers.sh` — captures headers from a Claude Code request via mitmproxy and diffs against the previous capture. Only the `oauth-*` beta flag is compared; other beta flags (thinking, caching, etc.) are filtered out as noise.
- `statusline-command.sh` — Claude Code statusline script that displays git info, battery, usage %, version, and header-change alerts.
- `~/.claw-header-detect/` — runtime directory for captured headers, extracted values, and change notices.

When a new Claude Code version is detected, the statusline auto-triggers a capture and alerts if any relevant headers changed (meaning the usage API call may need updating).
