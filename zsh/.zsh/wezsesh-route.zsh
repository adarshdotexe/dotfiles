# wezsesh-route - land a WezTerm mux pane in its project directory.
#
# This is the "sesh attach" half of the workflow, run entirely on whichever
# host the pane lives on (local WSL or a remote over the WezTerm ssh mux).
# It exists because the Windows GUI cannot safely serialize a cwd/args spawn
# payload into a Unix mux domain (the OsString-on-Unix bug). So instead of the
# client telling the remote where to go, the pane reads its own workspace name
# ("HOST:session") off the mux and resolves the session through zoxide locally.
#
# Sourced automatically via ~/.zsh/*.zsh. Safe to run anywhere: it no-ops
# unless we are an interactive shell inside a fresh WezTerm mux pane.

_wezsesh_route() {
  emulate -L zsh

  [[ -o interactive ]] || return 0
  [[ -n "${WEZTERM_PANE:-}" ]] || return 0
  command -v wezterm >/dev/null 2>&1 || return 0
  command -v zoxide >/dev/null 2>&1 || return 0

  # Run at most once per pane.
  local marker="${TMPDIR:-/tmp}/.wezsesh-routed.${WEZTERM_PANE}"
  [[ -e "$marker" ]] && return 0
  : > "$marker" 2>/dev/null || true

  # Only auto-jump from a pristine landing spot; never yank an existing cwd.
  [[ "$PWD" == "$HOME" ]] || return 0

  # Find this pane's workspace name in the mux table (col 3 = pane id,
  # col 4 = workspace). Plain text avoids a json parser dependency.
  local workspace
  workspace=$(wezterm cli list 2>/dev/null \
    | awk -v p="$WEZTERM_PANE" 'NR>1 && $3==p {print $4; exit}')
  [[ -n "$workspace" ]] || return 0

  # Workspace is "HOST:session"; the project key is everything after the ':'.
  local session="${workspace#*:}"
  [[ "$session" == "$workspace" ]] && return 0   # no ':' -> nothing to route
  case "$session" in
    ''|default|main|home) return 0 ;;
  esac

  local target
  target=$(zoxide query -- "$session" 2>/dev/null) || return 0
  [[ -n "$target" && -d "$target" && "$target" != "$PWD" ]] || return 0

  builtin cd -- "$target" 2>/dev/null && zoxide add -- "$target" 2>/dev/null
}

_wezsesh_route
