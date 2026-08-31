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

## Claude Code through Codex (`claudex`)

`claudex` runs the normal Claude Code harness against a local CLIProxyAPI instance authenticated with Codex OAuth. Plain `claude` remains unchanged.

- Install with `brew install cliproxyapi` and authenticate with `cliproxyapi -codex-login`.
- Before starting the service, configure `host: "127.0.0.1"` and a generated `api-keys` entry (for example, from `openssl rand -hex 24`) in `$(brew --prefix)/etc/cliproxyapi.conf`; then run `brew services start cliproxyapi`.
- Put the same local API key in `~/.config/op/cliproxyapi.env`. Literal values and `op://` references are both supported; set `CLIPROXY_OP_ACCOUNT` when more than one 1Password account is available. See `op/cliproxyapi.env.example`.
- The zsh/fish wrappers enable gateway model discovery and the effort UI. They intentionally do not pin a model; select one with `/model` or pass `--model` to `claudex`.

## Codex Statusline (`codex/`)

Codex CLI does not currently support Claude-style command-backed statusline scripts. Use Codex's built-in `[tui].status_line` item list instead.

- `statusline.config.toml` — preferred compact Codex statusline items: model/reasoning, cwd, git branch, context remaining, and Codex version. It also keeps TUI shortcut tooltips enabled and pins `Ctrl+T` as the transcript shortcut.
- `ls-tools --fix` symlinks it to `~/.codex/statusline.config.toml`.
- `ls-tools` checks whether `~/.codex/config.toml` defines blank `GH_AUTH_TOKEN` and `FA_AUTH_TOKEN` values for Codex tool-runner child processes; `ls-tools --fix` adds those defaults when missing.
- The shell config wraps `codex` as `command codex --profile statusline ...` when the profile file exists, but only for the runtime subcommands that accept `--profile` (bare TUI, flag-first invocations, and `exec`/`review`/`resume`/`archive`/`unarchive`/`fork`/`mcp`/`sandbox`/`debug`). Management commands like `codex update`/`login` get a plain `command codex ...`, since `--profile` errors on them. This layers the repo-tracked statusline profile on top of the machine-local `~/.codex/config.toml` without taking ownership of auth/app/plugin/project-trust config.

## Tool-name wrappers (old name points at new tool)

Gordon's long-standing convention: when he adopts a replacement tool, the *old* command name is pointed at the new tool instead of retraining muscle memory. Two live examples, both in `fishconfig/personal.d/general.fish` and `zshconfig/personal.d/general.zsh`:

- **`vim`/`gvim` → neovide.** The editor chain is SSH-vim > neovide > mvim > gvim > vim. Only the neovide branch needs special handling: neovide has its own clap-based CLI parser (it wraps neovim, it isn't one), so vim-native flags (`-R`, `-u`, `-c`, ...) must be passed after a `--` separator to reach the underlying nvim process, or neovide's own parser rejects them outright (`unexpected argument '-R' found`). `vim`/`gvim` are therefore real shell functions in the neovide branch — `neovide --no-fork -- $argv`/`"$@"` — not plain aliases; the mvim/gvim-real branches are real vim binaries and don't need this.
- **`grep` → ripgrep (`rg`).** Lives in its own file (`fishconfig/personal.d/grep-ripgrep.fish` / `zshconfig/personal.d/grep-ripgrep.zsh`) rather than `general.*`, since the function is sizeable. A function gated on `rg` being installed (`__tool_check_cmd "ripgrep" rg search-tools`), falling back to the old `grep --color=auto` alias if not. The flag mapping started from what Gordon actually types — mined from his real shell history via **atuin** (`atuin search --search-mode fulltext --filter-mode global --cmd-only grep`; his real history tool, not raw `fish_history`/`.zsh_history`) — but this wrapper replaces `grep` for *every* caller in the shell, not just interactive typing, so it also has to survive third-party scripts sourced at startup:
  - `-r`/`-R`/`-I` are dropped: rg recurses and skips binary files by default already.
  - `-E` is dropped: rg's regex is already ERE-like by default. Critically, none of `-r`, `-I`, `-E` can just pass through unchanged — rg's own `-r`/`-E` take a required value (`--replace`/`--encoding`), so an unstripped `-r`/`-E` would silently eat the next argument, and rg's own `-I` means `--no-filename`, not "ignore binary".
  - `-h` is translated to rg's `-I` (`--no-filename`), since rg's own `-h` is `--help`.
  - `-i`/`-n`/`-v`/`-c`/`-l`/`-L`/`-o`/`-w`/`-x`/`-q`/`-s` pass through unchanged — identical meaning in both tools.
  - Bundled short flags (e.g. `-cvE`) **are** expanded to individual flags before the above rules apply — this isn't optional: iTerm2's shell integration script (`iterm2_shell_integration.fish`) calls `grep -cvE '...'` on every fish startup, and an unbundled-only wrapper broke it, silently passing `-cvE` straight to rg and crashing shell init. Expansion only fires when every letter in the bundle is a recognized one; an unrecognized bundle passes through untouched so rg fails loudly on it rather than being silently misinterpreted.

When adding or changing one of these wrappers: re-survey real usage via atuin rather than guessing at flag coverage, and check whether the wrapper needs arg-rewriting (use a function) or just a fixed prefix (an alias is fine).

`command <name>` (e.g. `command grep`, `command vim`) always reaches the real underlying binary, bypassing the wrapper.

**Internal call sites must not depend on the interactive wrapper.** Anything in `personal.d/*.zsh`/`personal.d/*.fish` that calls a wrapped command for its own logic (not as a user-facing convenience) should call `command grep`/`command vim`/etc. explicitly, so it keeps exact upstream semantics regardless of what the wrapper does. Current examples: `node-version-switch.zsh`/`.fish`'s `.tool-versions` check (`command grep -qE '^nodejs[[:space:]]'`), and the Codex `GH_AUTH_TOKEN`/`FA_AUTH_TOKEN` config checks and pyenv `virtualenv-init` check in `00-tools.*`/`general.*`. This isn't optional hardening — the `grep -qE` node-version-switch check broke silently under the `rg` wrapper (bundled `-qE` wasn't in its strip list) until this fix landed.

## OpenCode CLI

OpenCode should be installed as a standalone binary, not as a global npm package, on these machines.

Preferred install paths:

- `curl -fsSL https://opencode.ai/install | bash` — installs to the first available install directory, with `$HOME/.opencode/bin` as the fallback. This repo already prepends `$HOME/.opencode/bin` to PATH.
- `brew install anomalyco/tap/opencode` — also acceptable, independent of project Node versions.

Avoid `npm install -g opencode-ai`, `bun install -g opencode-ai`, `pnpm install -g opencode-ai`, and `yarn global add opencode-ai` unless explicitly debugging package-manager installs. These methods create package-manager/global shims and make install/update behavior depend on whichever Node/package-manager environment is active. In this repo, asdf shims are per-project and intentionally move with Node versions, so an npm-global `opencode` can drift or shadow the standalone binary.

OpenCode config notes:

- Global config lives at `~/.config/opencode/opencode.json`; TUI config lives at `~/.config/opencode/tui.json`.
- Project config is `opencode.json` at the repo root and is merged with global config, not a full replacement.
- `opencode/tui.json` is symlinked to `~/.config/opencode/tui.json` by `ls-tools --fix`.
- This repo's `opencode.json` includes `AGENT.md` as an instruction file so OpenCode gets the same project guidance without duplicating it into `AGENTS.md`.
- OpenCode does not currently expose a configurable statusline or command-backed statusline hook. Use `tui.json` for supported TUI settings only; do not add statusline keys unless they appear in `https://opencode.ai/tui.json`.
- OpenCode reads `AGENTS.md`; `/init` can generate one, but this repo already maintains `AGENT.md` for Codex-specific notes and should use `AGENTS.md` only if OpenCode needs project-facing instructions.
- Troubleshooting cue: only if OpenCode behaves like the wrong install is being used, check `which opencode` and `asdf which opencode`/`~/.asdf/shims/opencode`. Prefer `/opt/homebrew/bin/opencode` or `$HOME/.opencode/bin/opencode`; remove stale asdf/npm shims rather than changing PATH broadly.
