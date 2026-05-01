#!/usr/bin/env bash
# Read-only check of GPG trust state against tigconfig/gpg-trust.conf.
# Prints a status summary and copy-pasteable fix commands for any mismatch.
# Never modifies the keyring or trust DB — by design, fixes are user-driven.

set -u

shell_config="${SHELL_CONFIG:-$HOME/src/shell-config}"
manifest="$shell_config/tigconfig/gpg-trust.conf"

if [[ ! -r "$manifest" ]]; then
  echo "gpg-trust-check: manifest not found at $manifest" >&2
  exit 1
fi

case "$(uname -s)" in
  Darwin) gpg_candidates=(/opt/homebrew/bin/gpg /usr/local/bin/gpg /usr/bin/gpg) ;;
  *)      gpg_candidates=(/usr/bin/gpg /usr/local/bin/gpg /home/linuxbrew/.linuxbrew/bin/gpg) ;;
esac

real_gpg=""
for c in "${gpg_candidates[@]}"; do
  [[ -x "$c" ]] && { real_gpg="$c"; break; }
done
if [[ -z "$real_gpg" ]]; then
  echo "gpg-trust-check: gpg binary not found" >&2
  exit 127
fi

# date-from-epoch helper (BSD `date -r` on macOS, GNU `date -d "@..."` on Linux)
fmt_epoch() {
  case "$(uname -s)" in
    Darwin) date -r "$1" "+%Y-%m-%d" 2>/dev/null ;;
    *)      date -d "@$1" "+%Y-%m-%d" 2>/dev/null ;;
  esac
}

if [[ -t 1 ]]; then
  red=$(tput setaf 1 2>/dev/null) || red=""
  green=$(tput setaf 2 2>/dev/null) || green=""
  yellow=$(tput setaf 3 2>/dev/null) || yellow=""
  bold=$(tput bold 2>/dev/null) || bold=""
  reset=$(tput sgr0 2>/dev/null) || reset=""
else
  red=""; green=""; yellow=""; bold=""; reset=""
fi

now=$(date +%s)
warn_seconds=$(( 30 * 86400 ))

issues=0
warnings=0
total=0

printf "%sGPG trust chain%s\n" "$bold" "$reset"

while IFS= read -r line; do
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" ]] && continue

  read -r fp expected desc <<< "$line"
  total=$((total + 1))

  data=$("$real_gpg" --list-keys --with-colons "$fp" 2>/dev/null)
  if [[ -z "$data" ]]; then
    printf "  %s✗%s %s\n" "$red" "$reset" "$desc"
    printf "      %sMissing from keyring.%s\n" "$bold" "$reset"
    printf "      Try: gpg --keyserver keys.openpgp.org --recv-keys %s\n" "$fp"
    issues=$((issues + 1))
    continue
  fi

  pub_line=$(printf '%s\n' "$data" | grep -m1 '^pub:')
  IFS=':' read -ra f <<< "$pub_line"
  validity="${f[1]}"
  expiry="${f[6]}"

  expiry_status=ok
  if [[ -n "$expiry" && "$expiry" != "0" ]]; then
    if (( expiry < now )); then
      expiry_status=expired
    elif (( expiry < now + warn_seconds )); then
      expiry_status=expiring
    fi
  fi

  if [[ "$validity" == "e" || "$expiry_status" == "expired" ]]; then
    expiry_date=$(fmt_epoch "$expiry" || echo unknown)
    printf "  %s✗%s %s\n" "$red" "$reset" "$desc"
    printf "      %sExpired%s on %s.\n" "$bold" "$reset" "$expiry_date"
    if [[ "$expected" == "ultimate" ]]; then
      printf "      Renew: gpg --edit-key %s → expire → set new expiry → save\n" "$fp"
      printf "             then re-export the public key and update each machine.\n"
    else
      printf "      Re-import: fetch the new key from its source.\n"
    fi
    issues=$((issues + 1))
    continue
  fi

  case "$expected" in
    ultimate)
      if [[ "$validity" != "u" ]]; then
        printf "  %s⚠%s  %s\n" "$yellow" "$reset" "$desc"
        printf "      Trust not set to ultimate (validity=%s).\n" "$validity"
        printf "      Fix: gpg --edit-key %s → trust → 5 → y → save\n" "$fp"
        issues=$((issues + 1))
        continue
      fi
      ;;
    full)
      if [[ "$validity" != "f" && "$validity" != "u" ]]; then
        printf "  %s⚠%s  %s\n" "$yellow" "$reset" "$desc"
        printf "      Trust not set to full (validity=%s).\n" "$validity"
        printf "      Fix: gpg --edit-key %s → trust → 4 → y → save\n" "$fp"
        printf "           gpg --lsign-key %s\n" "$fp"
        issues=$((issues + 1))
        continue
      fi
      ;;
    *)
      printf "  %s⚠%s  %s — unknown trust level '%s' in manifest\n" "$yellow" "$reset" "$desc" "$expected"
      issues=$((issues + 1))
      continue
      ;;
  esac

  if [[ "$expiry_status" == "expiring" ]]; then
    expiry_date=$(fmt_epoch "$expiry" || echo unknown)
    days_left=$(( (expiry - now) / 86400 ))
    printf "  %s⚠%s  %s — %sexpires in %d days%s (%s)\n" \
      "$yellow" "$reset" "$desc" "$bold" "$days_left" "$reset" "$expiry_date"
    if [[ "$expected" == "ultimate" ]]; then
      printf "      Renew: gpg --edit-key %s → expire → set new expiry → save\n" "$fp"
    fi
    warnings=$((warnings + 1))
  else
    printf "  %s✓%s %s\n" "$green" "$reset" "$desc"
  fi
done < "$manifest"

echo ""
if (( issues > 0 )); then
  printf "%s%d issue(s)%s, %d warning(s), %d total\n" "$red" "$issues" "$reset" "$warnings" "$total"
  exit 1
elif (( warnings > 0 )); then
  printf "%s%d warning(s)%s, %d total\n" "$yellow" "$warnings" "$reset" "$total"
fi
