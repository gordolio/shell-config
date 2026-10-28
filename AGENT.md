# Shell Config

## Commit Rules

- Keep `Co-Authored-By` trailers on agent-assisted commits, in every repo, Trio upstream work included, so the history shows how each commit was made. This used to be the opposite: a global `commit-msg` hook stripped them, which was dropped on 2026-10-25. Don't reintroduce it.

## Codex CLI

Codex CLI must be installed via Homebrew on every machine — `brew install --cask codex`, update with `brew upgrade --cask codex`. **Never** `npm install -g @openai/codex`.

The Homebrew codex is a standalone Rust binary with no node dependency. The npm-global install instead ties codex to whatever node version asdf has active, and node versions are swapped per-project on nearly every machine — an npm-global codex would drift or break. The asdf shims (`~/.asdf/shims/`) are all node-ecosystem CLIs; an `npm -g` codex would create a `~/.asdf/shims/codex` shim that shadows the native binary.

No shell-config change is needed for this — `/opt/homebrew/bin` is already on PATH ahead of where it matters, and no `codex` asdf shim should exist. Do **not** routinely check for one.

`codex` resolves to `bin/codex` (POSIX `sh`, symlinked to `~/bin/codex` by `ls-tools --fix`, ahead of Homebrew on PATH). It reads `OPENAI_API_KEY` from `~/.config/op/codex.env` (see `op/codex.env.example`) with `op read`, then execs `/opt/homebrew/bin/codex` with top-level `-c` overrides for a custom provider whose `env_key` is `OPENAI_API_KEY`. Codex ignores `OPENAI_API_KEY` in the environment for its built-in provider and only reads `~/.codex/auth.json`, which is why it needs the provider. Top-level `-c` is accepted by every subcommand, unlike `--profile`. `--version`/`help`/`completion`/`login`/`logout`/`update` skip the 1Password read. If no key resolves, codex launches unchanged and falls back to `auth.json`.

Troubleshooting cue: only if someone is asking about codex here and it sounds like an environment problem (codex behaving oddly, wrong version, node-coupling symptoms) — check for a stale `~/.asdf/shims/codex`, and if found, recommend removing it (`which -a codex` should list `~/bin/codex`, then `/opt/homebrew/bin/codex`). If a shim keeps reappearing, the structural fix is a PATH helper pushing `/opt/homebrew/bin` ahead of `~/.asdf/shims`; otherwise just delete the shim and leave PATH alone.

## Claude Code Statusline (`claude/`)

The `claude/` directory contains the statusline script and hooks for Claude Code.

- `statusline-command.sh` — Claude Code statusline script that displays the vim-mode chip, model, user, path, git info, time, version, and context/usage dot bars. Uses data from Claude Code's statusline JSON input (no external API calls needed).
- `gh-guard.py` — `PreToolUse` hook that lets `gh` run freely except for high-blast-radius commands (repo delete/archive/rename/edit, deploy keys, release create/edit/delete/upload, secret/variable set/delete, `pr merge --admin`, `alias set`/`import` and `extension install`/`exec`, and any non-GET `gh api` call, since raw API writes, aliases and extensions can reach all of those). Commands are found after `;`/`&&`/`|`, newlines, `$(...)`/backticks, `VAR=` prefixes, wrappers like `env`/`sudo`/`xargs`, and inside `bash -c "..."`. A match returns `permissionDecision: "ask"`, a native approval prompt, not a hard deny. Rules are subcommand prefixes plus optional required flags; `gh api` matches as `api read`/`api write`.
  - Per-machine policy goes in the untracked `~/.config/claude/gh-guard.json`: `{"deny": ["pr create", "api"], "allow": ["release create"]}`. `deny` adds rules, `allow` drops default rules by exact string. A missing file means the loose default. An unreadable or invalid file asks on every `gh` command instead of falling back to loose, so a typo can't silently unlock a strict machine.

The hook is symlinked into `~/.claude/hooks/` by `ls-tools --fix`.

There is deliberately no commit gate. The old `confirm-git-commit.sh` (Beyond Compare + approval dialog on every commit/`--continue`), the read-only `gh-allowlist.py`, and `git-push-allowlist.py` (agents could only push a brand-new, non-protected branch) were retired on 2026-10-25: with current frontier models the per-commit review was friction rather than protection. Commits and pushes go through Claude Code's normal permission mode, and review happens after the fact.

- `fix-settings.sh` — run by `ls-tools --fix` (like `gitconfig/fix-local.sh`); `--check` mode feeds the `claude-settings` row in `ls-tools`. Idempotently merges into `~/.claude/settings.json` the `statusLine` entry, the `gh-guard.py` `PreToolUse` registration (matcher `Bash`), and iTerm2's Claude Code integration hook (`~/.config/iterm2/cc-status` on every event iTerm2's wizard registers), plus the `cc-status` symlink into the iTerm2 app bundle. It only adds entries whose command isn't already registered for that event and never touches other keys. The one exception is `retired_hooks`: their registrations are removed from every event and their dangling `~/.claude/hooks/` symlinks deleted, so a hook dropped from the repo stops firing on every machine at its next `ls-tools --fix`. When retiring a hook, add it there instead of just deleting its entry from `wanted`. `settings.json` itself is deliberately not tracked or symlinked: Claude Code, `/config`, plugin toggles and iTerm2's wizard all write to it.

The rest of iTerm2's Claude Code integration (Python API enabled, Session Status toolbelt tool, the "Claude Code" workgroup with Chat/Diff/Code Review sessions) is plain iTerm2 prefs in the tracked `iterm2config/com.googlecode.iterm2.plist`. If a newer iTerm2 hooks more events, re-run its wizard on one machine and copy the new events into `iterm_events` in `fix-settings.sh`.

## GnuPG pinentry (`gnupgconfig/`)

- `pinentry-ide.sh` — the pinentry dispatcher `gpg-agent.conf` points at, symlinked into place by `ls-tools --fix`.
- `fix-pinentry-fallback.sh` — machine-local, idempotent, run by `ls-tools --fix` (like `gitconfig/fix-local.sh`). Sets `pinentry-program /opt/homebrew/bin/pinentry-mac` in `~/.gnupg/gpg-agent.conf.bak`, only touching that one key.

The IDE (WebStorm/git4idea) owns `pinentry-ide.sh` and regenerates it — unconditionally, on every git-config or git-executable change once its embedded-pinentry feature has configured `gpg-agent.conf` — stripping comments and rewriting the `IJ_PINENTRY*` branches with absolute paths every time. That regeneration itself cannot be turned off without also killing the IDE's in-editor GPG passphrase prompt, so fighting it is pointless; the tracked file will keep diffing whenever the IDE touches it, and that's fine.

What *is* controllable is the fallback line the IDE writes for everything that isn't its own `IJ_PINENTRY*` case. Per `GpgAgentConfigurator.kt` in `intellij-community`, the regenerator reads `pinentry-program` out of `~/.gnupg/gpg-agent.conf.bak` if present, and only falls back to a live `gpgconf --list-components` lookup otherwise. That backup file is normally only written once, the first time the IDE configures pinentry — and only if a `gpg-agent.conf` already existed to back up. On a fresh machine it usually doesn't, so the IDE falls through to `gpgconf`, which resolves to `pinentry-curses` on these Macs — needs a controlling tty, fails outright for scripts/hooks/agent shells. `fix-pinentry-fallback.sh` preempts that by keeping `gpg-agent.conf.bak` pointed at `pinentry-mac`, which works from any process, so every IDE regeneration bakes in the working fallback instead of the broken one.

The tracked `pinentry-ide.sh` (with its explanatory comments and an `if -x pinentry-mac` guard) is deliberately kept richer than what the IDE writes — it's documentation-of-intent plus a symlink tripwire: an IDE overwrite either shows as a git diff here or replaces the symlink (`not_symlink` in `ls-tools`), so a regression surfaces instead of silently breaking headless signing. This has already happened once. It only protects you once committed: an overwrite of an uncommitted file leaves nothing to diff against. Don't expect the diff to go away — just check that the fallback line in the live file still says `pinentry-mac`.

## Claude Code through Codex (`claudex`)

`claudex` runs the normal Claude Code harness against a local CLIProxyAPI instance authenticated with Codex OAuth. Plain `claude` remains unchanged.

- Install with `brew install cliproxyapi` and authenticate with `cliproxyapi -codex-login`.
- Before starting the service, configure `host: "127.0.0.1"` and a generated `api-keys` entry (for example, from `openssl rand -hex 24`) in `$(brew --prefix)/etc/cliproxyapi.conf`; then run `brew services start cliproxyapi`.
- Put the same local API key in `~/.config/op/cliproxyapi.env`. Literal values and `op://` references are both supported; set `CLIPROXY_OP_ACCOUNT` when more than one 1Password account is available. See `op/cliproxyapi.env.example`.
- The zsh wrapper (`zshconfig/personal.d/claudex.zsh`) enables gateway model discovery and the effort UI. It intentionally does not pin a model; select one with `/model` or pass `--model` to `claudex`.

## Codex Statusline (`codex/`)

Codex CLI does not currently support Claude-style command-backed statusline scripts. Use Codex's built-in `[tui].status_line` item list instead.

- `statusline.config.toml` — preferred compact Codex statusline items: model/reasoning, cwd, git branch, context remaining, and Codex version. It also keeps TUI shortcut tooltips enabled and pins `Ctrl+T` as the transcript shortcut.
- `ls-tools --fix` symlinks it to `~/.codex/statusline.config.toml`.
- `ls-tools` checks whether `~/.codex/config.toml` defines blank `GH_AUTH_TOKEN` and `FA_AUTH_TOKEN` values for Codex tool-runner child processes; `ls-tools --fix` adds those defaults when missing.
- The shell config wraps `codex` as `command codex --profile statusline ...` when the profile file exists, but only for the runtime subcommands that accept `--profile` (bare TUI, flag-first invocations, and `exec`/`review`/`resume`/`archive`/`unarchive`/`fork`/`mcp`/`sandbox`/`debug`). Management commands like `codex update`/`login` get a plain `command codex ...`, since `--profile` errors on them. This layers the repo-tracked statusline profile on top of the machine-local `~/.codex/config.toml` without taking ownership of auth/app/plugin/project-trust config.

## Zsh startup layers (`zshconfig/`)

zsh is the only shell configured here (fish was removed on 2026-10-18). The macOS login shell is deliberately left alone — no `/etc/shells` edits or `chsh`; iTerm2's profiles run `/opt/homebrew/bin/zsh` as their command instead. That makes iTerm2's zsh a non-login shell started with only the system PATH and `SHELL` still naming the login shell, so `env.zsh` runs `path_helper` itself when the shell isn't a login shell, and the interactive layer exports `SHELL` as zsh. iTerm2 auto-saves its in-memory settings to `iterm2config/` on any settings change, so edit that plist only while iTerm2 is closed, or it gets overwritten.

Startup is split by who it's for:

- **`env.zsh` + `env.d/*.zsh` — everyone, humans and agents.** PATH entries, exports, and wrappers that decide whether a command works or is safe: the npm/yarn/pnpm/npx wrappers (registry-token placeholders, 1Password on installs, the Prisma guard), the git wrapper's token injection for `commit`/`push`/`ai` hooks, `dx`, `yaak`. Loaded by `zprofile` (login shells — Codex's `zsh -lc` reads only this path, never `.zshrc`) and by `zshrc`; a plain-variable guard makes the second load a no-op. Keep it cheap: no `eval "$(tool init)"`, no network, no prompts. Agent startup is ~10-30ms.
- **`zshrc` past `[[ -o interactive ]] || return` + `personal.d/` — interactive only.** Plugins, prompt, completions, key bindings, `ls-tools`, and wrappers that only change output or swap the tool (grep→rg, ls→eza, vim→neovide, `which`, `tar`, brew tips, git-linkify). Agents run non-interactive shells, so none of this reaches them. Claude Code snapshots whatever `~/.zshrc` defines from a non-interactive login shell, which therefore stops at the interactive check.
- **Secrets stay out of the everyone layer.** `HOMEBREW_GITHUB_API_TOKEN` and the legacy GD keys are interactive-only, so agent shells never carry a GitHub token (see `gh-allowlist.py`).

Things that are easy to break:

- `__tool_add_path ... prepend` moves an already-present entry to the front instead of leaving it. Login shells run macOS's `path_helper` (`/etc/zprofile`) before `.zprofile`, and it pushes an inherited PATH behind `/usr/bin`; without the move, nested login shells and agents started from a terminal got Apple's git/perl/python.
- `env.d/zz-path-priority.zsh` runs last so asdf's shims win over pyenv, bun, Homebrew's node, nvm, and SDKMAN. It also puts SDKMAN's candidates and nvm's default node on PATH without loading either; `sdk` and `nvm` load on first use (eager nvm.sh was ~400ms).
- pyenv (and pyenv-virtualenv) init output is cached by `__cached_eval` in `zshrc` under `~/.cache/zsh/`, keyed on the resolved binary path so Homebrew upgrades regenerate it. oh-my-posh is not cached: its init output carries a per-session id.
- `compinit` runs its full check at most once a day (`-C` otherwise). Delete `~/.zcompdump` to pick up newly installed completions immediately.
- Profile startup with `ZSH_PROFILE_STARTUP=1 zsh -i -c exit`.
- Machine-local additions go in `env.d/*-local.zsh` (agents too) or `personal.d/*-local.zsh` (interactive only); both are gitignored.

## Tool-name wrappers (old name points at new tool)

Gordon's long-standing convention: when he adopts a replacement tool, the *old* command name is pointed at the new tool instead of retraining muscle memory. Two live examples, both in `zshconfig/personal.d/general.zsh`. Like everything in `personal.d/`, they only exist in interactive shells — agents get the real binaries (see "Zsh startup layers" above):

- **`vim`/`gvim` → neovide.** The editor chain is SSH-vim > neovide > mvim > gvim > vim. Only the neovide branch needs special handling: neovide has its own clap-based CLI parser (it wraps neovim, it isn't one), so vim-native flags (`-R`, `-u`, `-c`, ...) must be passed after a `--` separator to reach the underlying nvim process, or neovide's own parser rejects them outright (`unexpected argument '-R' found`). `vim`/`gvim` are therefore real shell functions in the neovide branch — `neovide --no-fork -- $argv`/`"$@"` — not plain aliases; the mvim/gvim-real branches are real vim binaries and don't need this.
- **`grep` → ripgrep (`rg`).** Lives in its own file (`zshconfig/personal.d/grep-ripgrep.zsh`) rather than `general.zsh`, since the function is sizeable. A function gated on `rg` being installed (`__tool_check_cmd "ripgrep" rg search-tools`), falling back to the old `grep --color=auto` alias if not. The flag mapping started from what Gordon actually types — mined from his real shell history via **atuin** (`atuin search --search-mode fulltext --filter-mode global --cmd-only grep`; his real history tool, not raw `.zsh_history`) — but this wrapper replaces `grep` for *every* caller in an interactive shell, not just typing, so it also has to survive third-party scripts sourced at startup:
  - The 2026-08-31 human-authored Atuin survey found direct `grep` use with `-r`, `-i`, `-I`, `-n`, `-v`, `-E`, and BSD `-O`, plus plain piped searches. Direct `rg` use was either bare or `rg -n ... -S ...`; the wrapper does not alter `rg` itself.
  - `-r`/`-R`/`-I` are dropped: rg recurses and skips binary files by default already. On the BSD grep used on these Macs, `-R` does not itself enable symlink following; that is the separate `-S` option.
  - BSD grep's `-O` is dropped: rg already follows explicitly named symlinks while not following symlinks discovered during traversal. Include `O` in bundled-flag expansion so `-rO` cannot reach rg as its unrelated `-r/--replace` option.
  - `-E` is dropped: rg's regex is already ERE-like by default. Critically, none of `-r`, `-I`, `-E` can just pass through unchanged — rg's own `-r`/`-E` take a required value (`--replace`/`--encoding`), so an unstripped `-r`/`-E` would silently eat the next argument, and rg's own `-I` means `--no-filename`, not "ignore binary".
  - `-h` is translated to rg's `-I` (`--no-filename`), since rg's own `-h` is `--help`.
  - `-L` is translated to `--files-without-match`, since rg's `-L` instead means `--follow`.
  - `-s` is translated to `--no-messages`, since rg's `-s` instead means `--case-sensitive`.
  - `-i`/`-n`/`-v`/`-c`/`-l`/`-o`/`-w`/`-x`/`-q` pass through unchanged — identical meaning in both tools.
  - Bundled short flags (e.g. `-cvE`) **are** expanded to individual flags before the above rules apply — this isn't optional: back when fish was the shell, iTerm2's shell integration script (`iterm2_shell_integration.fish`) called `grep -cvE '...'` on every startup, and an unbundled-only wrapper broke it, silently passing `-cvE` straight to rg and crashing shell init. Expansion only fires when every letter in the bundle is a recognized one; an unrecognized bundle passes through untouched so rg fails loudly on it rather than being silently misinterpreted.

When adding or changing one of these wrappers: re-survey real usage via atuin rather than guessing at flag coverage, and check whether the wrapper needs arg-rewriting (use a function) or just a fixed prefix (an alias is fine).

`command <name>` (e.g. `command grep`, `command vim`) always reaches the real underlying binary, bypassing the wrapper.

**Internal call sites must not depend on the interactive wrapper.** Anything in `env.d/*.zsh`/`personal.d/*.zsh` that calls a wrapped command for its own logic (not as a user-facing convenience) should call `command grep`/`command vim`/etc. explicitly, so it keeps exact upstream semantics regardless of what the wrapper does. Current examples: `env.d/node-version-switch.zsh`'s `.tool-versions` check (`command grep -qE '^nodejs[[:space:]]'`), and the Codex `GH_AUTH_TOKEN`/`FA_AUTH_TOKEN` config checks in `personal.d/00-tools.zsh`. This isn't optional hardening — the `grep -qE` node-version-switch check broke silently under the `rg` wrapper (bundled `-qE` wasn't in its strip list) until this fix landed.

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
- `opencode` resolves to `bin/opencode` (a POSIX `sh` script, symlinked to `~/bin/opencode` by `ls-tools --fix`; `~/bin` is prepended to PATH ahead of Homebrew). It injects `ANTHROPIC_API_KEY`/`OPENAI_API_KEY`/`GOOGLE_GENERATIVE_AI_API_KEY`/`LINEAR_API_KEY`/`FIGMA_API_KEY` from `~/.config/op/opencode.env` (see `op/opencode.env.example`), then execs the standalone binary (`/opt/homebrew/bin/opencode`, else `$HOME/.opencode/bin/opencode`). A script rather than a fish/zsh function so non-shell launchers (Raycast, OpenChamber, IDEs) and `model-check` get the same keys. It resolves each secret with `op read` and exports it, never `op run` — `op run` proxies stdio to mask secrets, which breaks a TUI's terminal-size detection and SIGWINCH passthrough (opencode is always interactive, unlike npm/yarn/pnpm's install-only `op run` path in `js-package-managers.*`).
- `omo4` (`bin/omo4`, symlinked to `~/bin/omo4`) launches OpenCode on the pinned `oh-my-openagent@4.19.4` plugin via `bin/opencode`, after checking that `~/.config/opencode/opencode.jsonc` still pins it and that `~/.omo/omo.jsonc` has only keys v4's strict schema accepts (OMO 5 Native shares that file and adds `[native]`). `omo4 check` runs the check only; `omo4 restore` copies the v4 config back from `~/.config-backups/omo4-20261001/` (full v4 backup of config, skills, auth and hooks lives there).

## Git identity and commit signing (`gitconfig/`)

`gitconfig/gitconfig` (tracked here, symlinked to `~/.gitconfig`) sets a default identity at the top level and layers per-directory overrides on top via `includeIf "gitdir:..."`, so work repositories get a different identity and signing key from personal ones.

- The per-directory config files the `includeIf` entries point at are **machine-local and not tracked in this repo**. They hold the work identity and signing key. The `includeIf` plumbing arrives for free on a new machine via the symlinked `gitconfig/gitconfig`, but those files do not — recreate them by hand when setting up a new machine, or work commits silently use the personal identity.
- `~/.gitconfig.local` (machine-local, regenerated idempotently by `gitconfig/fix-local.sh`, included unconditionally near the bottom of `gitconfig/gitconfig`) sets only `gpg.program` and `cz-ai.backend`. It does not set identity or signing key, so it never overrides the choice above.

**Planned, not yet done:** a separate signing key for the personal identity, so open-source commits get signed too. The top-level `[user]` section already applies only outside the `includeIf` directories, so this needs no change to the work configs — just a `signingkey` and `commit.gpgsign` at the top level of `gitconfig/gitconfig` once the key exists.

Key generation (`gpg --full-generate-key`) is run by hand, not on anyone's behalf — it touches `~/.gnupg`.
