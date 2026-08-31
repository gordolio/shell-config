# grep -> rg wrapper. Flag mapping is based on actual usage surveyed from
# shell history (2026-08-31), plus real bundled-flag calls hit by third-party
# scripts sourced at startup (iTerm2's shell integration calls `grep -cvE`):
# only -r/-R, -i, -I, -n, -v, -h, -E, -c, -l, -L, -o, -w, -x, -q, -s ever appear,
# bundled or not. -r/-R/-I/-E are dropped: rg recurses and skips binaries by
# default, and its regex is already ERE-like, so none of them are needed --
# and passing them through would be actively wrong, since rg's -r/-E each
# consume the next argument as a value (--replace/--encoding), and rg's -I
# means --no-filename, not "ignore binary". -h is translated to rg's -I
# (--no-filename) since rg's own -h is --help. The rest carry the same
# meaning in both tools. Bundled short flags (e.g. -cvE) are expanded to
# individual flags first, but ONLY when every letter in the bundle is one of
# the ones above -- an unrecognized bundle is passed through untouched so rg
# fails loudly on it instead of being silently misinterpreted.
# Use `command grep` for the real grep.
if __tool_check_cmd "ripgrep" rg search-tools
  function grep
    set -l known_flags r R i I n v h E c l L o w x q s
    set -l flat
    for a in $argv
      if string match -qr -- '^-[a-zA-Z]{2,}$' $a
        set -l chars (string split '' -- (string sub -s 2 -- $a))
        set -l all_known 1
        for c in $chars
          if not contains -- $c $known_flags
            set all_known 0
            break
          end
        end
        if test $all_known -eq 1
          for c in $chars
            set -a flat "-$c"
          end
          continue
        end
      end
      set -a flat $a
    end
    set -l out
    for a in $flat
      switch $a
        case -r -R -I -E
          # no-op: already rg's default behavior
        case -h
          set -a out -I
        case '*'
          set -a out $a
      end
    end
    rg $out
  end
else
  alias grep "grep --color=auto"
end
