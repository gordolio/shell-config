#!/bin/bash
#
# shai-hulud-check.sh — local triage for the Shai-Hulud npm supply-chain worm
#
# Covers indicators from the Sept 2025 wave, the Nov 2025 "2.0" wave, and the
# May 2026 dead-man's-switch artifacts. Runs a fast HOST triage, then hands off
# to the maintained community detector for the full dependency-graph audit
# (2,700+ known bad package versions):
#   https://github.com/Cobenian/shai-hulud-detect
# That repo is auto-cloned to ~/src/shai-hulud-detect and `git pull`-ed on
# every run so the package list stays current.

set -u

usage() {
  cat <<'EOF'
shai-hulud-check — local triage for the Shai-Hulud npm supply-chain worm

Usage:
  shai-hulud-check [options] [scan-root ...]

Arguments:
  scan-root        One or more directories to scan. Defaults to $HOME.

Options:
  --no-detector    Skip the Cobenian dependency-graph audit (host triage only).
  -h, --help       Show this help and exit.

The Cobenian detector is cloned to ~/src/shai-hulud-detect on first run and
git-pulled on every run so its known-bad package list stays current.

Exit status: 0 = clean, 1 = suspicious findings, 2 = usage error.
EOF
}

RUN_DETECTOR=1
ARGS=()
for a in "$@"; do
  case "$a" in
    --no-detector) RUN_DETECTOR=0 ;;
    -h|--help)     usage; exit 0 ;;
    --*)           usage >&2; exit 2 ;;
    *)             ARGS+=("$a") ;;
  esac
done
set -- "${ARGS[@]}"

HITS=0
WARN=0

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

hit()  { red   "  [PWNED?] $*"; HITS=$((HITS+1)); }
warn() { ylw   "  [CHECK ] $*"; WARN=$((WARN+1)); }
ok()   { grn   "  [ ok   ] $*"; }

ROOTS=("$@")
[ ${#ROOTS[@]} -eq 0 ] && ROOTS=("$HOME")

# Directories that are noisy / not worth descending into.
PRUNE=( -name node_modules -o -name .git -o -name Library -o -name .Trash \
        -o -name .cache -o -name .venv -o -name venv -o -name site-packages )

# ---------------------------------------------------------------------------
hdr "1. Malicious payload files (worm drops these by name)"
# Filenames the worm writes. bundle.js is also a legit name, so it is a WARN.
MAL_NAMES=( setup_bun.js bun_environment.js router_runtime.js tanstack_runner.js \
            router_init.js )
for root in "${ROOTS[@]}"; do
  [ -d "$root" ] || continue
  for n in "${MAL_NAMES[@]}"; do
    while IFS= read -r f; do
      [ -n "$f" ] && hit "payload file: $f"
    done < <(find "$root" \( "${PRUNE[@]}" \) -prune -o -type f -name "$n" -print 2>/dev/null)
  done
  # Mini-variant obfuscated credential stealer: FilePII_<hex>.js
  while IFS= read -r f; do
    [ -n "$f" ] && hit "credential-stealer file: $f"
  done < <(find "$root" \( "${PRUNE[@]}" \) -prune -o -type f -name 'FilePII_*.js' -print 2>/dev/null)
done
[ $HITS -eq 0 ] && ok "no known payload filenames found"

# ---------------------------------------------------------------------------
hdr "2. Persistence in .claude / .vscode configs"
# 2.0 plants hooks in agent/editor configs so it re-runs on every project open.
for root in "${ROOTS[@]}"; do
  [ -d "$root" ] || continue
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    # truffle[h]og: the [h] is a one-char regex class so this script does not
    # itself contain the literal word, which other scanners flag as an IOC.
    if grep -lEi 'setup_bun|bun_environment|router_runtime|shai.?hulud|truffle[h]og' \
         "$f" >/dev/null 2>&1; then
      hit "tainted config references worm payload: $f"
    fi
  done < <(find "$root" \( "${PRUNE[@]}" \) -prune -o -type f \
             \( -path '*/.claude/settings.json' -o -path '*/.claude/setup.mjs' \
                -o -path '*/.vscode/tasks.json' \) -print 2>/dev/null)
done
# These specific drop files should never exist outside the worm.
for root in "${ROOTS[@]}"; do
  [ -d "$root" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] && hit "worm bootstrap file: $f"
  done < <(find "$root" \( "${PRUNE[@]}" \) -prune -o -type f \
             -path '*/.claude/setup.mjs' -print 2>/dev/null)
done

# ---------------------------------------------------------------------------
hdr "3. May-2026 dead-man's-switch artifacts in \$HOME"
for a in gh-token-monitor kitty-monitor; do
  if find "$HOME" -maxdepth 3 -name "*${a}*" -print 2>/dev/null | grep -q .; then
    find "$HOME" -maxdepth 3 -name "*${a}*" 2>/dev/null | while read -r f; do
      hit "dead-man's-switch artifact: $f"
    done
  fi
done

# ---------------------------------------------------------------------------
hdr "4. Malicious GitHub Actions self-hosted runner"
# 2.0 registers a runner literally named SHA1HULUD.
if find / -maxdepth 6 -type d -name '_diag' -path '*actions-runner*' 2>/dev/null | grep -q .; then
  warn "self-hosted actions-runner present — inspect runner name for 'SHA1HULUD'"
fi
if pgrep -fl 'Runner.Listener' >/dev/null 2>&1; then
  warn "Runner.Listener process active — confirm it is yours"
fi
if pgrep -fl 'bun run' >/dev/null 2>&1; then
  warn "a 'bun run' process is active:"; pgrep -fl 'bun run' | sed 's/^/         /'
fi

# ---------------------------------------------------------------------------
hdr "5. npm cache — attacker repo clones"
# Worm clones attacker-controlled forks into the npm cacache tmp dir.
NPMCACHE="${HOME}/.npm/_cacache/tmp"
if [ -d "$NPMCACHE" ] && find "$NPMCACHE" -maxdepth 1 -name 'git-clone*' 2>/dev/null | grep -q .; then
  warn "git-clone* dirs in npm cache ($NPMCACHE) — usually transient, inspect if persistent"
fi

# ---------------------------------------------------------------------------
hdr "6. Exfiltration / C2 strings in first-party source"
# Match strings specific to the worm, and report file:line:match so hits can
# be judged quickly. Vendored dependency trees are excluded on purpose: legit
# cloud SDKs (aws-sdk, googleauth, ...) reference the IMDS IP 169.254.169.254
# constantly, so a hit there is noise — only first-party code is worth a look.
PATTERNS='Sha1-Hulud: The Second Coming|SHA1HULUD|bun_environment\.js|webhook\.site|169\.254\.169\.254'
SKIP_DIRS=( node_modules .git Library .cache vendor .venv venv dist build \
            site-packages shai-hulud-detect test-cases )
EXCLUDES=()
for d in "${SKIP_DIRS[@]}"; do EXCLUDES+=( --exclude-dir="$d" ); done
for root in "${ROOTS[@]}"; do
  [ -d "$root" ] || continue
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    case "$m" in *shai-hulud-check*) continue ;; esac   # don't flag this tool
    warn "$m"
  done < <(grep -rInE "$PATTERNS" "$root" "${EXCLUDES[@]}" 2>/dev/null | head -40)
done

# ---------------------------------------------------------------------------
hdr "7. GitHub account exposure (manual — needs gh + your judgement)"
if command -v gh >/dev/null 2>&1; then
  echo "  Check your account for worm artifacts:"
  echo "    gh repo list --json name,description,isPrivate -L 200 \\"
  echo "      | grep -iE 'shai.?hulud|migration|the second coming'"
  echo "    gh api /user/repos --paginate -q '.[].name' | grep -i hulud"
  echo "  Also look for: unexpected PUBLIC repos, repos named random hex,"
  echo "  commits authored as 'Linus Torvalds', and a workflow file"
  echo "  '.github/workflows/shai-hulud-workflow.yml' in any repo."
else
  echo "  gh CLI not installed — manually review github.com/<you>?tab=repositories"
  echo "  for unexpected public repos and a 'Shai-Hulud' marker repo."
fi

# ---------------------------------------------------------------------------
hdr "8. Dependency-graph audit (Cobenian/shai-hulud-detect)"
DETECTOR_DIR="$HOME/src/shai-hulud-detect"
DETECTOR_URL="https://github.com/Cobenian/shai-hulud-detect.git"
if [ "$RUN_DETECTOR" -eq 0 ]; then
  echo "  skipped (--no-detector)"
elif ! command -v git >/dev/null 2>&1; then
  warn "git not installed — cannot clone/update the detector; skipping"
else
  # Clone on first run, otherwise fast-forward to the latest package list.
  if [ -d "$DETECTOR_DIR/.git" ]; then
    if git -C "$DETECTOR_DIR" pull --ff-only --quiet 2>/dev/null; then
      ok "detector updated ($DETECTOR_DIR)"
    else
      warn "could not update detector (offline?) — using existing checkout"
    fi
  else
    echo "  cloning detector to $DETECTOR_DIR ..."
    if git clone --depth 1 --quiet "$DETECTOR_URL" "$DETECTOR_DIR" 2>/dev/null; then
      ok "detector cloned"
    else
      warn "could not clone detector (offline?) — skipping dependency audit"
    fi
  fi

  DETECTOR_SH="$DETECTOR_DIR/shai-hulud-detector.sh"
  if [ -x "$DETECTOR_SH" ] || [ -f "$DETECTOR_SH" ]; then
    for root in "${ROOTS[@]}"; do
      [ -d "$root" ] || continue
      echo
      echo "  --- detector scan: $root ---"
      if bash "$DETECTOR_SH" "$root" --check-host; then
        :
      else
        warn "detector reported findings for $root — review its output above"
      fi
    done
  elif [ -d "$DETECTOR_DIR/.git" ]; then
    warn "detector script not found at $DETECTOR_SH — repo layout may have changed"
  fi
fi

# ---------------------------------------------------------------------------
hdr "Result"
echo
if [ $HITS -gt 0 ]; then
  red  "$HITS strong host indicator(s) found. Treat machine as compromised:"
  echo "  - Rotate ALL credentials: npm tokens, GitHub PAT/SSH keys, AWS/Azure/GCP,"
  echo "    and any crypto wallet seeds. Do this from a clean machine."
  echo "  - Audit your GitHub account for new public repos / unknown commits."
  echo "  - Re-read the detector output (section 8) for compromised packages."
  exit 1
elif [ $WARN -gt 0 ]; then
  ylw "$WARN item(s) need a manual look — review the sections flagged above."
  echo "  WARN includes anything the dependency detector reported in section 8."
  exit 1
else
  grn "No Shai-Hulud indicators found — host triage and dependency audit clean."
  exit 0
fi
