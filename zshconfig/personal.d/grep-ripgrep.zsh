# grep -> rg wrapper. Flag mapping is based on actual usage surveyed from
# shell history (2026-08-31), plus real bundled-flag calls hit by third-party
# scripts sourced at startup (iTerm2's fish integration calls `grep -cvE`;
# nothing similar found in its zsh integration, but harden the same way here
# since this wraps grep for every caller, not just interactive typing):
# only -r/-R, -i, -I, -n, -v, -h, -E, -c, -l, -L, -o, -w, -x, -q, -s ever
# appear, bundled or not. -r/-R/-I/-E are dropped: rg recurses and skips
# binaries by default, and its regex is already ERE-like, so none of them are
# needed -- and passing them through would be actively wrong, since rg's
# -r/-E each consume the next argument as a value (--replace/--encoding), and
# rg's -I means --no-filename, not "ignore binary". -h is translated to rg's
# -I (--no-filename) since rg's own -h is --help. The rest carry the same
# meaning in both tools. Bundled short flags (e.g. -cvE) are expanded to
# individual flags first, but ONLY when every letter in the bundle is one of
# the ones above -- an unrecognized bundle is passed through untouched so rg
# fails loudly on it instead of being silently misinterpreted.
# Use `command grep` for the real grep.
if __tool_check_cmd "ripgrep" rg search-tools; then
  grep() {
    local known_flags="rRiInvhElLowxqsc"
    local -a flat=()
    local a body c
    local -i i ok
    for a in "$@"; do
      if [[ "$a" =~ ^-[A-Za-z][A-Za-z]+$ ]]; then
        body="${a#-}"
        ok=1
        for (( i = 1; i <= ${#body}; i++ )); do
          c="${body[i]}"
          [[ "$known_flags" == *"$c"* ]] || { ok=0; break }
        done
        if (( ok )); then
          for (( i = 1; i <= ${#body}; i++ )); do
            flat+=("-${body[i]}")
          done
          continue
        fi
      fi
      flat+=("$a")
    done
    local -a out=()
    for a in "${flat[@]}"; do
      case "$a" in
        -r|-R|-I|-E) ;;
        -h) out+=(-I) ;;
        *) out+=("$a") ;;
      esac
    done
    rg "${out[@]}"
  }
else
  alias grep="grep --color=auto"
fi
