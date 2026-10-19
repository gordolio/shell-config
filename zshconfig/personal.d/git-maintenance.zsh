# git gc/repack helper: scans repos under a root dir, shows a live scan
# progress list, then lets you pick which repos to gc/repack via fzf.
# Interactive only (fzf, cursor-movement redraw), so it lives in personal.d/.

function __ggc_human_kb {
  local kb=$1
  if (( kb < 1024 )); then
    printf '%dK' $kb
  elif (( kb < 1048576 )); then
    printf '%.1fM' $(( kb / 1024.0 ))
  else
    printf '%.1fG' $(( kb / 1024.0 / 1024 ))
  fi
}

function __ggc_dot {
  local color
  case "$1" in
    ok)    color=$'\e[32m' ;;
    maybe) color=$'\e[33m' ;;
    gc)    color=$'\e[31m' ;;
    *)     color=$'\e[0m' ;;
  esac
  printf '%s●%s' "$color" $'\e[0m'
}

# One scan result -> one display row. A result is git-repo-health.pl's
# tab-delimited summary: severity, state, loose, packs, reclaim_kb, total_kb, path.
function __ggc_format_row {
  local root=$1 result=$2
  local -a f=("${(@ps:\t:)result}")
  printf '%s %-42s loose:%-6s packs:%-4s reclaim:~%-8s size:%s' \
    "$(__ggc_dot ${f[2]})" "${f[7]#"$root"/}" ${f[3]} ${f[4]} \
    "$(__ggc_human_kb ${f[5]})" "$(__ggc_human_kb ${f[6]})"
}

function ggc {
  local health=$HOME/src/shell-config/bin/git-repo-health.pl
  if [[ ! -x $health ]]; then
    print -u2 "ggc: missing or non-executable: $health"
    return 1
  fi

  local root=${1:-$HOME/src}
  root=${root%/}

  local -a repo_dirs=()
  local git_dir
  while IFS= read -r git_dir; do
    repo_dirs+=("${git_dir%/.git}")
  done < <(find "$root" -maxdepth 6 \( -name node_modules -prune \) -o \( -type d -name .git -print -prune \) 2>/dev/null)

  if (( ${#repo_dirs} == 0 )); then
    print "ggc: no git repos found under $root"
    return 1
  fi

  # Scan every repo in the background. `&!` disowns the job so the shell prints
  # no "[1] 12345" / "done" notices over the progress list.
  local n=${#repo_dirs}
  local tmpdir i
  tmpdir=$(mktemp -d -t ggc-scan) || return 1
  local -a pids=()
  for (( i = 1; i <= n; i++ )); do
    "$health" "${repo_dirs[i]}" >"$tmpdir/$i.out" 2>"$tmpdir/$i.err" &!
    pids+=($!)
  done

  # Redraw the list in place until every scan has exited. results[i] is the raw
  # summary line, rows[i] its display text; both are filled once, when scan i finishes.
  local -a spinner_frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  local -a results=() rows=() lines
  local erase=$'\e[2K'
  local frame=1 first_draw=1 running rel
  while true; do
    running=0
    lines=()
    for (( i = 1; i <= n; i++ )); do
      rel=${repo_dirs[i]#"$root"/}
      if [[ -z ${rows[i]} ]]; then
        if kill -0 ${pids[i]} 2>/dev/null; then
          running=1
          lines+=("$erase  ${spinner_frames[frame]} $rel")
          continue
        fi
        results[i]=$(cat "$tmpdir/$i.out" 2>/dev/null)
        if [[ -n ${results[i]} ]]; then
          rows[i]=$(__ggc_format_row "$root" "${results[i]}")
        else
          rows[i]="✗ $rel (scan failed — see $tmpdir/$i.err)"
        fi
      fi
      lines+=("$erase  ${rows[i]}")
    done

    (( first_draw )) || printf '\e[%dA' $n
    first_draw=0
    printf '%s\n' "${lines[@]}"

    (( running )) || break
    frame=$(( frame % 10 + 1 ))
    sleep 0.08
  done

  # Menu lines are severity<TAB>row<TAB>path, so fzf shows only the row (field 2)
  # and previews/returns the path (field 3).
  local tab=$'\t'
  local -a f menu=()
  for (( i = 1; i <= n; i++ )); do
    [[ -n ${results[i]} ]] || continue
    f=("${(@ps:\t:)results[i]}")
    menu+=("${f[1]}${tab}${rows[i]}${tab}${f[7]}")
  done
  rm -rf "$tmpdir"

  if (( ${#menu} == 0 )); then
    print "ggc: no repos scanned successfully"
    return 1
  fi

  local picked
  picked=$(printf '%s\n' "${menu[@]}" | sort -t "$tab" -k1,1rn | fzf --multi --ansi \
    --header=$'Keys:\n  SPACE toggle • CTRL-A all • CTRL-D none • CTRL-T invert\n  Type to filter • ENTER choose action for selected • ESC cancel' \
    --delimiter="$tab" \
    --with-nth=2 \
    --bind='space:toggle,ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all' \
    --pointer='▶' \
    --marker='✓' \
    --color='pointer:#00d7ff,marker:#ffd75f,hl:#00d7ff,hl+:#00d7ff,fg:#c0c0c0,bg:#1c1c1c,fg+:#ffffff,bg+:#262626,info:#ffd75f,prompt:#87ff87,header:#87afff' \
    --preview="$health --detail {3}" \
    --preview-window='right:60%:wrap')

  [[ -n $picked ]] || return 0

  local -a repo_paths=()
  local line
  for line in "${(@f)picked}"; do
    f=("${(@ps:\t:)line}")
    repo_paths+=("${f[3]}")
  done

  local -a actions=(
    "git gc"
    "git gc --aggressive"
    "git repack -a -d -f --depth=250 --window=250"
    "git maintenance run --task=gc"
  )
  local action
  action=$(printf '%s\n' "${actions[@]}" | fzf --header="Action for ${#repo_paths} selected repo(s) • ESC cancels" --height='~40%')
  [[ -n $action ]] || return 0

  # Each action is "git <args>"; drop the "git " and word-split the rest.
  local -a git_args=(${=action#git })

  print "Note: gc prunes unreachable objects (default 2-week grace period on dangling commits/stashes)."

  local repo before after rc
  for repo in "${repo_paths[@]}"; do
    before=$(du -sk "$repo/.git" 2>/dev/null | cut -f1)
    print "== $repo =="
    command git -C "$repo" "${git_args[@]}"
    rc=$?
    after=$(du -sk "$repo/.git" 2>/dev/null | cut -f1)
    if (( rc == 0 )); then
      print "  freed: $(__ggc_human_kb $(( before - after ))) (${before}K -> ${after}K)"
    else
      print "  failed (exit $rc), left as-is"
    fi
  done
}
