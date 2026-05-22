# Shell Config

## Commit Rules

- **Never** add `Co-Authored-By` trailers to git commits.

## Codex CLI

Codex CLI must be installed via Homebrew on every machine — `brew install --cask codex`, update with `brew upgrade --cask codex`. **Never** `npm install -g @openai/codex`.

The Homebrew codex is a standalone Rust binary with no node dependency. The npm-global install instead ties codex to whatever node version asdf has active, and node versions are swapped per-project on nearly every machine — an npm-global codex would drift or break. The asdf shims (`~/.asdf/shims/`) are all node-ecosystem CLIs; an `npm -g` codex would create a `~/.asdf/shims/codex` shim that shadows the native binary.

No shell-config change is needed for this — `/opt/homebrew/bin` is already on PATH ahead of where it matters, and no `codex` asdf shim should exist. Do **not** routinely check for one.

Troubleshooting cue: only if someone is asking about codex here and it sounds like an environment problem (codex behaving oddly, wrong version, node-coupling symptoms) — check for a stale `~/.asdf/shims/codex`, and if found, recommend removing it (`which codex` should be `/opt/homebrew/bin/codex`). If a shim keeps reappearing, the structural fix is a PATH helper pushing `/opt/homebrew/bin` ahead of `~/.asdf/shims`; otherwise just delete the shim and leave PATH alone.

## Claude Code Statusline (`claude/`)

The `claude/` directory contains the statusline script for Claude Code.

- `statusline-command.sh` — Claude Code statusline script that displays the vim-mode chip, model, user, path, git info, time, version, and context/usage dot bars. Uses data from Claude Code's statusline JSON input (no external API calls needed).
