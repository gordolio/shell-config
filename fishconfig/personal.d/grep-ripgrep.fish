# grep -> rg wrapper. Flag mapping is based on actual usage surveyed from
# shell history (2026-08-31), plus real bundled-flag calls hit by third-party
# scripts sourced at startup (iTerm2's shell integration calls `grep -cvE`):
# human-authored history uses -r/-i/-I/-n/-v/-E/-O. The startup call and the
# established compatibility set additionally cover -R/-h/-c/-l/-L/-o/-w/-x/
# -q/-s. -r/-I/-E/-O are dropped because rg already
# recurses, skips binaries, uses regexes, and follows explicitly named symlinks
# by default. grep's -L becomes --files-without-match; grep's -s becomes
# --no-messages; and grep's -h becomes rg's -I/--no-filename. The others have
# meaning. Bundled short flags (e.g. -cvE) are expanded to
# individual flags first, but ONLY when every letter in the bundle is one of
# the ones above -- an unrecognized bundle is passed through untouched so rg
# fails loudly on it instead of being silently misinterpreted.
# Use `command grep` for the real grep.
if __tool_check_cmd "ripgrep" rg search-tools
  function grep
    set -l known_flags r R i I n v h E c l L o O w x q s
    set -l flat
    set -l options_done 0
    for a in $argv
      if test $options_done -eq 1
        set -a flat $a
        continue
      else if test "$a" = --
        set options_done 1
        set -a flat $a
        continue
      end
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
    set options_done 0
    for a in $flat
      if test $options_done -eq 1
        set -a out $a
        continue
      else if test "$a" = --
        set options_done 1
        set -a out $a
        continue
      end
      switch $a
        case -r -R -I -E -O
          # no-op: already rg's default behavior
        case -h
          set -a out -I
        case -L
          set -a out --files-without-match
        case -s
          set -a out --no-messages
        case '*'
          set -a out $a
      end
    end
    rg $out
  end
else
  alias grep "grep --color=auto"
end
