# tt — open a remote tmux/sesh session via mosh, ranked by frecency (zoxide-style).
#
#   tt                  fzf picker, highest frecency on top
#   tt <query>          jump to highest-frecency match of "host session"
#   tt -a HOST SESSION  add/promote without launching
#   tt -l               debug: print ranked list with scores
#
# DB: $HOME/.config/tt/db.tsv (per-host, no sync). Format: HOST\tSESSION\tRANK\tLAST_USED
# Frecency: rank * factor(age) — <1h:4x, <1d:2x, <1w:0.5x, else 0.25x.
#
# On WSL with wt.exe interop → opens a Windows Terminal tab.
# On a remote / no interop → just runs mosh in the current shell.

_tt_db() {
  local d="${TT_DB:-$HOME/.config/tt/db.tsv}"
  mkdir -p "$(dirname "$d")"
  [[ -f "$d" ]] || : > "$d"
  echo "$d"
}

_tt_seed() {
  local db; db=$(_tt_db)
  local cfg="$HOME/.ssh/config"
  [[ -r "$cfg" ]] || return
  # Hosts come from ssh-config. Session names are arbitrary (whatever sesh
  # finds on the remote: tmux ls, zoxide, ssh hosts), so we don't constrain
  # them. tt just tracks which (host, session) pairs you've launched.
  local hosts
  hosts=$(awk 'tolower($1)=="host"{for(i=2;i<=NF;i++)if($i!~/[*?]/&&$i!="")print $i}' "$cfg" | sort -u)

  local validhosts=$(mktemp) tmp=$(mktemp)
  for h in ${(f)hosts}; do printf '%s\n' "$h" >> "$validhosts"; done

  # Drop entries whose host isn't in ssh-config. Seed a "main" session per
  # host so first-time `tt` isn't empty. Existing (host, session) rows stay
  # untouched as long as the host is still valid.
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
  # Print: score \t host \t session \t rank \t last  (sorted desc by score)
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

_tt_launch() {
  local host="$1" session="$2"
  local sesh_arg="${session//\'/\'\\\'\'}"
  # `bash -lc` on the remote so /etc/profile + ~/.profile load — mosh-server's
  # exec'd shell is neither interactive nor invoked-via-rsh, so without -l it
  # skips both .bashrc and .profile and PATH is missing ~/.local/bin (sesh).
  local inner="export TT_HOST_ALIAS=$host && (tmux set-environment -g TT_HOST_ALIAS $host 2>/dev/null || true) && exec sesh connect '$sesh_arg'"
  local remote="MOSH_TITLE_NOPREFIX=1 LC_ALL=C.UTF-8 LANG=C.UTF-8 mosh $host -- bash -lc \"$inner\""
  if command -v wt.exe >/dev/null 2>&1; then
    wt.exe -w 0 new-tab --title "$host:$session" \
      wsl.exe --cd '~' -- bash -lc "$remote"
  else
    eval "$remote"
  fi
}

_tt_promote() {
  local db="$1" host="$2" session="$3"
  local now; now=$(date +%s)
  local tmp; tmp=$(mktemp)
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
      _tt_promote "$db" "$h" "$s"
      echo "promoted: $h / $s"
      return
      ;;
  esac

  local picked
  if [[ $# -gt 0 ]]; then
    # zoxide-style: every arg must appear (case-insensitive) somewhere in
    # "<host> <session>". Highest-frecency hit wins.
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
  _tt_promote "$db" "$h" "$s"
  _tt_launch "$h" "$s"
}

alias t='tt'
