#!/usr/bin/env bash
# Drop-in for git's gpg.program. Replaces verbose gpg verify output with
# a single "Signer: <icon> <name>" line; passes everything else through to
# real gpg unchanged (signing, key management, etc.).
#
# Wired via gitconfig: [gpg] program = <abs path to this file>
#
# Icons use Nerd Font glyphs (U+F0791 check-decagram, U+F05C times-circle-o).

set -u

case "$(uname -s)" in
  Darwin) gpg_candidates=(/opt/homebrew/bin/gpg /usr/local/bin/gpg /usr/bin/gpg) ;;
  *)      gpg_candidates=(/usr/bin/gpg /usr/local/bin/gpg /home/linuxbrew/.linuxbrew/bin/gpg) ;;
esac

real_gpg=""
for candidate in "${gpg_candidates[@]}"; do
  if [[ -x "$candidate" ]]; then
    real_gpg="$candidate"
    break
  fi
done
if [[ -z "$real_gpg" ]]; then
  echo "gpg-clean-verify: real gpg binary not found" >&2
  exit 127
fi

is_verify=false
for arg in "$@"; do
  if [[ "$arg" == "--verify" ]]; then
    is_verify=true
    break
  fi
done

if ! $is_verify; then
  exec "$real_gpg" "$@"
fi

ok_icon=$(printf '\xf3\xb0\x9e\x91')   # U+F0791 nf-md-check_decagram (verified badge)
bad_icon=$(printf '\xef\x81\x9c')      # U+F05C nf-fa-times_circle_o
indent="    "

errfile=$(mktemp "${TMPDIR:-/tmp}/gpg-clean-verify.XXXXXX")
trap 'rm -f "$errfile"' EXIT

"$real_gpg" "$@" 2>"$errfile"
status=$?

sed -E "
  s/^gpg: Good signature from \"([^\"]+)\".*/Signer: ${indent}${ok_icon} \1/
  s/^gpg: BAD signature from \"([^\"]+)\".*/Signer-BAD: ${indent}${bad_icon} \1/
  s/^gpg: Can.t check signature.*/Signer-Unknown: ${indent}? (no public key)/
  /^gpg:/d
" "$errfile" >&2

exit $status
