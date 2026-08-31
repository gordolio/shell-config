# grep -> rg wrapper. Flag mapping is based on actual usage surveyed from
# shell history (2026-08-31), plus real bundled-flag calls hit by third-party
# scripts sourced at startup (iTerm2's fish integration calls `grep -cvE`;
# nothing similar found in its zsh integration, but harden the same way here
# since this wraps grep for every caller, not just interactive typing):
# human-authored history uses -r/-i/-I/-n/-v/-E/-O. The startup call and the
# established compatibility set additionally cover -R/-h/-c/-l/-L/-o/-w/-x/
# -q/-s. -r/-I/-E/-O are dropped because rg already
# recurses, skips binaries, uses regexes, and follows explicitly named symlinks
# by default. grep's -L becomes --files-without-match; grep's -s becomes
# --no-messages; and grep's -h becomes rg's -I/--no-filename. The others have
# same meaning. Bundled short flags (e.g. -cvE) are expanded to
# individual flags first, but ONLY when every letter in the bundle is one of
# the ones above -- an unrecognized bundle is passed through untouched so rg
# fails loudly on it instead of being silently misinterpreted.
# Use `command grep` for the real grep.
if __tool_check_cmd "ripgrep" rg search-tools; then
  grep() {
    local known_flags="rRiInvhElLoOwxqsc"
    local -a flat=()
    local a body c
    local -i i ok options_done=0
    for a in "$@"; do
      if (( options_done )); then
        flat+=("$a")
        continue
      elif [[ "$a" == -- ]]; then
        options_done=1
        flat+=("$a")
        continue
      fi
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
    options_done=0
    for a in "${flat[@]}"; do
      if (( options_done )); then
        out+=("$a")
        continue
      elif [[ "$a" == -- ]]; then
        options_done=1
        out+=("$a")
        continue
      fi
      case "$a" in
        -r|-R|-I|-E|-O) ;;
        -h) out+=(-I) ;;
        -L) out+=(--files-without-match) ;;
        -s) out+=(--no-messages) ;;
        *) out+=("$a") ;;
      esac
    done
    rg "${out[@]}"
  }
else
  alias grep="grep --color=auto"
fi
