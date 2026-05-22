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

## Codex Statusline (`codex/`)

Codex CLI does not currently support Claude-style command-backed statusline scripts. Use Codex's built-in `[tui].status_line` item list instead.

- `statusline.config.toml` — preferred compact Codex statusline items: model/reasoning, cwd, git branch, context remaining, and Codex version.
- `ls-tools --fix` symlinks it to `~/.codex/statusline.config.toml`.
- The shell config wraps `codex` as `command codex --profile-v2 statusline ...` when the profile file exists. This layers the repo-tracked statusline profile on top of the machine-local `~/.codex/config.toml` without taking ownership of auth/app/plugin/project-trust config.

## OpenCode CLI

OpenCode should be installed as a standalone binary, not as a global npm package, on these machines.

Preferred install paths:

- `curl -fsSL https://opencode.ai/install | bash` — installs to the first available install directory, with `$HOME/.opencode/bin` as the fallback. This repo already prepends `$HOME/.opencode/bin` to PATH.
- `brew install anomalyco/tap/opencode` — also acceptable, independent of project Node versions.

Avoid `npm install -g opencode-ai`, `bun install -g opencode-ai`, `pnpm install -g opencode-ai`, and `yarn global add opencode-ai` unless explicitly debugging package-manager installs. These methods create package-manager/global shims and make install/update behavior depend on whichever Node/package-manager environment is active. In this repo, asdf shims are per-project and intentionally move with Node versions, so an npm-global `opencode` can drift or shadow the standalone binary.

OpenCode config notes:

- Global config lives at `~/.config/opencode/opencode.json`; TUI config lives at `~/.config/opencode/tui.json`.
- Project config is `opencode.json` at the repo root and is merged with global config, not a full replacement.
- `opencode/tui.json` is symlinked to `~/.config/opencode/tui.json` by `ls-tools --fix`; it includes opencode-vim's `vim_enter_submit` setting so Enter submits from vim insert mode.
- This repo's `opencode.json` includes `AGENT.md` as an instruction file so OpenCode gets the same project guidance without duplicating it into `AGENTS.md`.
- OpenCode does not currently expose a configurable statusline or command-backed statusline hook. Use `tui.json` for supported TUI settings only; do not add statusline keys unless they appear in `https://opencode.ai/tui.json`.
- OpenCode reads `AGENTS.md`; `/init` can generate one, but this repo already maintains `AGENT.md` for Codex-specific notes and should use `AGENTS.md` only if OpenCode needs project-facing instructions.
- Troubleshooting cue: only if OpenCode behaves like the wrong install is being used, check `which opencode` and `asdf which opencode`/`~/.asdf/shims/opencode`. Prefer `/opt/homebrew/bin/opencode` or `$HOME/.opencode/bin/opencode`; remove stale asdf/npm shims rather than changing PATH broadly.
