# cchost — open a remote tmux session via mosh + sesh.
#
#   cchost HOST SESSION   direct
#   cchost HOST           pick session via fzf
#   cchost                pick host + session via fzf
#
# When run from WSL (wt.exe in PATH), opens a new Windows Terminal tab.
# When run from a remote host (BAN, SC, ...), runs mosh in the current
# terminal — useful for chaining: cchost BAN frappe.

_cchost_hosts() {
  awk '
    tolower($1) == "host" {
      for (i = 2; i <= NF; i++) {
        if ($i !~ /[*?]/ && $i != "") print $i
      }
    }
  ' "$HOME/.ssh/config" 2>/dev/null | sort -u
}

_cchost_sessions() {
  local toml="$HOME/repos/dotfiles/sesh/.config/sesh/sesh.toml"
  [[ -r "$toml" ]] || { echo main; return; }
  printf 'main\n'
  awk -F'"' '/^\s*name\s*=\s*"/{print $2}' "$toml"
}

cchost() {
  local host="$1" session="$2"

  if [[ -z "$host" ]]; then
    host=$(_cchost_hosts | fzf --prompt='host> ' --no-multi --height=40%) || return
  fi
  [[ -z "$host" ]] && return

  if [[ -z "$session" ]]; then
    session=$(_cchost_sessions | fzf --prompt="session on $host> " --no-multi --height=40%) || return
  fi
  [[ -z "$session" ]] && return

  local remote_cmd="LC_ALL=C.UTF-8 LANG=C.UTF-8 mosh $host -- sesh connect '$session'"

  if command -v wt.exe >/dev/null 2>&1; then
    # Running in WSL — open a new Windows Terminal tab.
    wt.exe -w 0 new-tab --title "$host:$session" \
      wsl.exe --cd '~' -- bash -lc "$remote_cmd"
  else
    # On a remote / no WT interop — just exec in the current terminal.
    eval "$remote_cmd"
  fi
}

# Quick aliases
alias ch='cchost'
