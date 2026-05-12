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

# Base64-encoded helper script body (source: dotfiles/windows/tt-launch.sh).
# Regenerate via: base64 -w0 dotfiles/windows/tt-launch.sh
_TT_LAUNCH_B64='IyEvdXNyL2Jpbi9lbnYgYmFzaAojIHR0LWxhdW5jaCDigJQgcmVtb3RlIGF0dGFjaCBoZWxwZXIuIEVtYmVkZGVkIGFzIGJhc2U2NCBpbiB0dC5wczEgLyB0dC56c2guCiMKIyBUaGlzIGZpbGUgaXMgdGhlIFNPVVJDRSBPRiBUUlVUSC4gVGhlIHdyYXBwZXJzICh0dC5wczEsIHR0LnpzaCkgYmFzZTY0LWVuY29kZQojIGl0cyBjb250ZW50cyBpbnRvIGEgY29uc3RhbnQuIE9uIGVhY2ggbGF1bmNoIHRoZSB3cmFwcGVyIHdyaXRlcyBhIGZyZXNoIGNvcHkKIyB0byB+Ly5sb2NhbC9iaW4vdHQtbGF1bmNoIG9uIHRoZSByZW1vdGUgYW5kIGV4ZWMncyBgYmFzaCA8ZmlsZT4gU0VTU0lPTmAgc28KIyB0aGF0IG1vc2gncyBQVFkgc3Vydml2ZXMgb24gc3RkaW4gKHBpcGluZyB0byBgYmFzaGAgd291bGQgcmVwbGFjZSBzdGRpbiB3aXRoCiMgdGhlIHBpcGUgYW5kIHRtdXggYXR0YWNoIHdvdWxkIGZhaWwgd2l0aCAib3BlbiB0ZXJtaW5hbCBmYWlsZWQ6IG5vdCBhCiMgdGVybWluYWwiKS4KIwojIFVzYWdlOiB0dC1sYXVuY2ggU0VTU0lPTgpzZXQgLWV1byBwaXBlZmFpbAoKIyBBbHdheXMtb24gdHJhY2UuIExpdmVzIGF0IH4vLmNhY2hlL3R0LWxhdW5jaC9sYXN0LWxhdW5jaC50cmFjZSBvbiB0aGUgcmVtb3RlLgpUUkFDRV9ESVI9IiRIT01FLy5jYWNoZS90dC1sYXVuY2giCm1rZGlyIC1wICIkVFJBQ0VfRElSIgpleGVjIDk+IiRUUkFDRV9ESVIvbGFzdC1sYXVuY2gudHJhY2UiCkJBU0hfWFRSQUNFRkQ9OQpQUzQ9JysgWyQoZGF0ZSArJUg6JU06JVMpXSAke0JBU0hfU09VUkNFIyMqL306JHtMSU5FTk99OiAnCnNldCAteAoKIyBWYWxpZGF0ZSBzZXNzaW9uIG5hbWUgKGRlZmVuc2UgaW4gZGVwdGgg4oCUIGFscmVhZHkgY2hlY2tlZCBob3N0LXNpZGUpLgpTRVNTSU9OPSIkezE6P21pc3Npbmcgc2Vzc2lvbiBuYW1lfSIKY2FzZSAiJFNFU1NJT04iIGluCiAgLSopIGVjaG8gInR0LWxhdW5jaDogc2Vzc2lvbiBtdXN0IG5vdCBzdGFydCB3aXRoICctJyIgPiYyOyBleGl0IDIgOzsKZXNhYwpwcmludGYgJyVzJyAiJFNFU1NJT04iIHwgZ3JlcCAtRXEgJ15bQS1aYS16MC05Ll8tXXsxLDY0fSQnIFwKICB8fCB7IGVjaG8gInR0LWxhdW5jaDogaW52YWxpZCBzZXNzaW9uIG5hbWUiID4mMjsgZXhpdCAyOyB9CgojIEV4cGxpY2l0IGVudiBhY3RpdmF0aW9uIOKAlCBsb2dpbiBiYXNoIG9uIFJvY2t5IDggZG9lc24ndCBzb3VyY2UgLmJhc2hyYywgYW5kCiMgbWljcm9tYW1iYSBhY3RpdmF0aW9uIGxpdmVzIGluIC5iYXNocmMgb24gdGhlc2UgaG9zdHMuIFNvdXJjZSB0aGUgdXN1YWwKIyBzdGFydHVwIGZpbGVzIHNvIFBBVEggcGlja3MgdXAgfi8ubG9jYWwvYmluIChzZXNoLCBtaWNyb21hbWJhKS4KIwojIFJlbGF4IHN0cmljdG5lc3MgYXJvdW5kIHRoZSBzb3VyY2VzOiBkaXN0cm9zJyByYyBmaWxlcyByb3V0aW5lbHkgcmVmZXJlbmNlCiMgdW5zZXQgdmFyaWFibGVzICgkSElTVENPTlRST0wsICRQUzEsIOKApikgd2hpY2ggdHJpcCBgc2V0IC11YCwgYW5kIHRoZXkgdXNlCiMgcGlwZWxpbmVzIHRoYXQgbWF5IGxlZ2l0aW1hdGVseSBoYXZlIG5vbi16ZXJvIGV4aXRzICgkcGlwZWZhaWwpLiBSZXN0b3JlCiMgdGhlIHN0cmljdCBtb2RlIGFmdGVyd2FyZHMuCnNldCArZXVvIHBpcGVmYWlsClsgLXIgL2V0Yy9wcm9maWxlIF0gJiYgLiAvZXRjL3Byb2ZpbGUKWyAtciAiJEhPTUUvLnByb2ZpbGUiIF0gJiYgLiAiJEhPTUUvLnByb2ZpbGUiClsgLXIgIiRIT01FLy5iYXNocmMiIF0gJiYgLiAiJEhPTUUvLmJhc2hyYyIKc2V0IC1ldW8gcGlwZWZhaWwKCiMgTWljcm9tYW1iYSBhY3RpdmF0aW9uIChuby1vcCBpZiBhYnNlbnQpLiBBY3RpdmF0ZXMgdGhlIGBkb3RmaWxlc2AgZW52IGlmCiMgcHJlc2VudCBzbyB0bXV4L3Nlc2ggZnJvbSB0aGF0IGVudiBsYW5kIG9uIFBBVEguCmlmIFsgLXggIiRIT01FLy5sb2NhbC9iaW4vbWljcm9tYW1iYSIgXTsgdGhlbgogIGV4cG9ydCBNQU1CQV9FWEU9IiRIT01FLy5sb2NhbC9iaW4vbWljcm9tYW1iYSIKICBleHBvcnQgTUFNQkFfUk9PVF9QUkVGSVg9IiR7TUFNQkFfUk9PVF9QUkVGSVg6LSRIT01FLy5sb2NhbC9taWNyb21hbWJhfSIKICBldmFsICIkKCIkTUFNQkFfRVhFIiBzaGVsbCBob29rIC0tc2hlbGwgYmFzaCkiCiAgWyAtZCAiJE1BTUJBX1JPT1RfUFJFRklYL2VudnMvZG90ZmlsZXMiIF0gJiYgbWljcm9tYW1iYSBhY3RpdmF0ZSBkb3RmaWxlcwpmaQoKZXhwb3J0IFRUX0hPU1RfQUxJQVM9IiR7VFRfSE9TVF9BTElBUzotJHtIT1NUTkFNRSUlLip9fSIKCiMgQnJvd3NlciBicmlkZ2U6IGFueSBwcm9jZXNzIHRoYXQgb3BlbnMgYSBVUkwgaW5zaWRlIHRoaXMgc2Vzc2lvbiBpcyByb3V0ZWQKIyB0aHJvdWdoIH4vLmxvY2FsL2Jpbi90dC1vcGVuLCB3aGljaCBQT1NUcyB0byB0aGUgV2luZG93cy1zaWRlIGxpc3RlbmVyIG92ZXIKIyB0aGUgZXQgcmV2ZXJzZS10dW5uZWwuIE91dHNpZGUgYW4gZXQgc2Vzc2lvbiB0aGUgY3VybCBmYWlscyBmYXN0IChzZWUKIyB0dC1vcGVuKS4gVGhlIHdyYXBwZXIgZXhwb3J0cyBCUk9XU0VSIGFscmVhZHksIGJ1dCB3ZSByZS1zZXQgaXQgaGVyZSBzbwojIGB0bXV4IG5ldy1zZXNzaW9uYCBpbmhlcml0cyBpdCBjbGVhbmx5IGludG8gdGhlIHNlc3Npb24gZW52LgppZiBbIC14ICIkSE9NRS8ubG9jYWwvYmluL3R0LW9wZW4iIF07IHRoZW4KICBleHBvcnQgQlJPV1NFUj0iJEhPTUUvLmxvY2FsL2Jpbi90dC1vcGVuIgpmaQoKIyB0bXV4IG11c3QgYmUgb24gUEFUSC4KY29tbWFuZCAtdiB0bXV4ID4vZGV2L251bGwgfHwgeyBlY2hvICJ0dC1sYXVuY2g6IHRtdXggbm90IG9uIFBBVEgiID4mMjsgZXhpdCAzOyB9CgojIDItdGllciBhdHRhY2ggbGFkZGVyOgojICAgMS4gc2VzaCBjb25uZWN0IOKAlCBoYW5kbGVzIGV4aXN0aW5nLXRtdXggKHByZWZpeCBtYXRjaCkgQU5EIHpveGlkZS1wYXRoIGNyZWF0ZQojICAgMi4gZmFsbGJhY2s6IHRtdXggbmV3LXNlc3Npb24gLUFzIOKAlCBmb3IgZ2VudWluZWx5LW5ldyBzZXNzaW9ucyBzZXNoIGRvZXNuJ3Qga25vdwppZiBjb21tYW5kIC12IHNlc2ggPi9kZXYvbnVsbCAyPiYxOyB0aGVuCiAgZXhlYyBzZXNoIGNvbm5lY3QgIiRTRVNTSU9OIiB8fCB0cnVlCmZpCmV4ZWMgdG11eCBuZXctc2Vzc2lvbiAtQXMgIiRTRVNTSU9OIgo='

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
  # Defense-in-depth session-name validation. The remote helper re-validates,
  # but rejecting here stops any wt/wsl tab from opening on bad input.
  if [[ $session == -* ]] || [[ ! $session =~ ^[A-Za-z0-9._-]{1,64}$ ]]; then
    print -u2 "tt: invalid session name '$session' — must match [A-Za-z0-9._-]{1,64} and not start with '-'"
    return 2
  fi
  local b64=$_TT_LAUNCH_B64
  if [[ $host == 'WSL' ]]; then
    # Local — bash directly (no transport). Inline remote-style payload so the
    # helper deployment + activation behaviour matches the et path exactly.
    local remote="export TT_HOST_ALIAS='WSL' && export BROWSER=tt-open && mkdir -p ~/.local/bin && echo $b64 | base64 -d > ~/.local/bin/tt-launch && chmod 0755 ~/.local/bin/tt-launch && exec bash ~/.local/bin/tt-launch '$session'"
    if command -v wt.exe >/dev/null 2>&1; then
      wt.exe -w 0 new-tab --title "WSL:$session" wsl.exe -- bash -c "$remote"
    else
      eval "$remote"
    fi
  else
    # Remote via EternalTerminal. tt-et-launch (installed in ~/.local/bin by
    # bootstrap.sh) bootstraps etserver on $host via SSH, opens the URL
    # reverse-tunnel, and invokes et with the inner tt-launch payload as a
    # positional arg. Calling it as a single argv keeps every parser between
    # us and et happy.
    if command -v wt.exe >/dev/null 2>&1; then
      wt.exe -w 0 new-tab --title "$host:$session" \
        wsl.exe -- bash -lc 'tt-et-launch "$@"' bash "$host" "$session" "$b64"
    else
      tt-et-launch "$host" "$session" "$b64"
    fi
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
