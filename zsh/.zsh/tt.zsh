# tt - open a WezTerm mux workspace, ranked by frecency (zoxide-style).
#
#   tt                  fzf picker, highest frecency on top
#   tt <query>          jump to highest-frecency match of "host session"
#   tt -n HOST SESSION  create/promote and launch
#   tt -a HOST SESSION  add/promote without launching
#   tt -l               debug: print ranked list with scores

_tt_db() {
  local d="${TT_DB:-$HOME/.config/tt/db.tsv}"
  mkdir -p "$(dirname "$d")"
  [[ -f "$d" ]] || : > "$d"
  echo "$d"
}

_tt_normalize_host() {
  case "$1" in
    [Ww][Ss][Ll]) echo WSL ;;
    *) echo "$1" ;;
  esac
}

_tt_seed() {
  local db; db=$(_tt_db)
  local cfg="$HOME/.ssh/config"
  local hosts="WSL"
  if [[ -r "$cfg" ]]; then
    hosts="${hosts}"$'\n'"$(awk 'tolower($1)=="host"{for(i=2;i<=NF;i++)if($i!~/[*?]/&&$i!="")print $i}' "$cfg" | sort -u)"
  fi

  local validhosts tmp
  validhosts=$(mktemp)
  tmp=$(mktemp)
  for h in ${(f)hosts}; do [[ -n "$h" ]] && printf '%s\n' "$h" >> "$validhosts"; done

  awk -F'\t' -v hf="$validhosts" '
    BEGIN {
      while ((getline line < hf) > 0) hosts[line] = 1
    }
    NF == 4 {
      if ($1 in hosts) { print; have[$1 FS $2] = 1 }
    }
    END {
      for (h in hosts) {
        k = h FS "main"
        if (!(k in have)) print h "\tmain\t0\t0"
      }
    }
  ' "$db" > "$tmp" && mv "$tmp" "$db"
  rm -f "$validhosts"
}

_tt_score_awk() {
  awk -v now="$(date +%s)" '
    BEGIN { FS = "\t"; OFS = "\t" }
    NF == 4 {
      rank=$3+0; last=$4+0
      if (last == 0) { score = rank }
      else {
        age = now - last
        if      (age < 3600)   factor = 4
        else if (age < 86400)  factor = 2
        else if (age < 604800) factor = 0.5
        else                   factor = 0.25
        score = rank * factor
      }
      printf "%.4f\t%s\t%s\t%s\t%s\n", score, $1, $2, $3, $4
    }
  ' "$1" | sort -k1,1 -g -r
}

_tt_find_wezterm() {
  local p
  for p in \
    "/mnt/c/Program Files/WezTerm/wezterm.exe" \
    "$HOME/scoop/apps/wezterm/current/wezterm.exe" \
    wezterm.exe; do
    if [[ "$p" == */* ]]; then
      [[ -x "$p" ]] && { echo "$p"; return 0; }
    elif command -v "$p" >/dev/null 2>&1; then
      command -v "$p"
      return 0
    fi
  done
  return 1
}

_tt_remote_home() {
  case "$1" in
    H100|GB100) echo /root ;;
    *) echo /home/advarshney ;;
  esac
}

_tt_workspace_exists() {
  local wezterm="$1" workspace="$2"
  command -v python3 >/dev/null 2>&1 || return 1
  "$wezterm" cli list --format json 2>/dev/null \
    | python3 -c 'import json,sys; ws=sys.argv[1]; rows=json.load(sys.stdin); sys.exit(0 if any(r.get("workspace") == ws for r in rows) else 1)' "$workspace"
}

_tt_launch() {
  local host="$(_tt_normalize_host "$1")" session="$2"
  if [[ $host == -* ]] || [[ ! $host =~ ^[A-Za-z0-9._-]{1,64}$ ]]; then
    print -u2 "tt: invalid host '$host' -- must match [A-Za-z0-9._-]{1,64} and not start with '-'"
    return 2
  fi
  if [[ $session == -* ]] || [[ ! $session =~ ^[A-Za-z0-9._-]{1,64}$ ]]; then
    print -u2 "tt: invalid session '$session' -- must match [A-Za-z0-9._-]{1,64} and not start with '-'"
    return 2
  fi

  local wezterm
  wezterm=$(_tt_find_wezterm) || {
    print -u2 "tt: wezterm.exe not found"
    return 1
  }

  local domain="$host" workspace="${host}:${session}"
  [[ "$host" == WSL ]] && domain=WSL

  # Avoid passing Windows-side spawn payloads into Unix mux domains; older
  # WezTerm releases can serialize them as Windows OsString values.
  "$wezterm" connect "$domain" --workspace "$workspace" >/dev/null 2>&1 &!
}

_tt_promote() {
  local db="$1" host="$(_tt_normalize_host "$2")" session="$3"
  local now tmp
  now=$(date +%s)
  tmp=$(mktemp)
  awk -v h="$host" -v s="$session" -v now="$now" '
    BEGIN { FS = OFS = "\t"; found = 0 }
    NF == 4 {
      if ($1 == h && $2 == s) { print $1, $2, $3 + 1, now; found = 1 }
      else                    { print }
    }
    END {
      if (!found) print h, s, 1, now
    }
  ' "$db" > "$tmp" && mv "$tmp" "$db"
}

tt() {
  local db; db=$(_tt_db)
  _tt_seed

  case "$1" in
    -n)
      shift
      local h="$1" s="$2"
      [[ -n "$h" && -n "$s" ]] || { echo "usage: tt -n HOST SESSION" >&2; return 1; }
      h=$(_tt_normalize_host "$h")
      _tt_promote "$db" "$h" "$s"
      _tt_launch "$h" "$s"
      return
      ;;
    -l)
      printf '%-12s %-10s %-25s %-8s %s\n' 'SCORE' 'RANK' 'AGE' 'HOST' 'SESSION'
      _tt_score_awk "$db" | awk -v now="$(date +%s)" '
        BEGIN { FS = "\t" }
        {
          score = $1; host = $2; sess = $3; rank = $4; last = $5
          if (last+0 == 0) age = "-"
          else { mins = int((now - last) / 60); age = mins "m" }
          printf "%-12s %-10s %-25s %-8s %s\n", score, rank, age, host, sess
        }
      '
      return
      ;;
    -a)
      shift
      local h="$1" s="$2"
      [[ -n "$h" && -n "$s" ]] || { echo "usage: tt -a HOST SESSION" >&2; return 1; }
      h=$(_tt_normalize_host "$h")
      _tt_promote "$db" "$h" "$s"
      echo "promoted: $h / $s"
      return
      ;;
  esac

  local picked
  if [[ $# -gt 0 ]]; then
    local pats="$*"
    picked=$(_tt_score_awk "$db" | awk -F'\t' -v pats="$pats" '
      BEGIN { n = split(pats, p, " ") }
      {
        haystack = tolower($2 " " $3)
        ok = 1
        for (i = 1; i <= n; i++) {
          if (index(haystack, tolower(p[i])) == 0) { ok = 0; break }
        }
        if (ok) { print $2 "\t" $3; exit }
      }
    ')

    [[ -z "$picked" ]] && {
      echo "no match for: $*  (use 'tt -n HOST SESSION' to launch a new one)" >&2
      return 1
    }
  else
    picked=$(_tt_score_awk "$db" \
      | awk -F'\t' '{print $2 "\t" $3}' \
      | fzf --reverse --no-multi --prompt 'tt> ' \
            --delimiter $'\t' --with-nth '1,2' \
            --header 'host / session (ranked by frecency)') || return
  fi
  [[ -z "$picked" ]] && return

  local h="${picked%%	*}" s="${picked#*	}"
  h=$(_tt_normalize_host "$h")
  _tt_promote "$db" "$h" "$s"
  _tt_launch "$h" "$s"
}

alias t='tt'
