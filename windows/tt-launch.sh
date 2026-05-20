#!/usr/bin/env bash
# tt-launch — remote attach helper. Embedded as base64 in tt.ps1 / tt.zsh.
#
# This file is the SOURCE OF TRUTH. The wrappers (tt.ps1, tt.zsh) base64-encode
# its contents into a constant. On each launch the wrapper writes a fresh copy
# to ~/.local/bin/tt-launch on the remote and exec's `bash <file> SESSION` so
# that mosh's PTY survives on stdin (piping to `bash` would replace stdin with
# the pipe and tmux attach would fail with "open terminal failed: not a
# terminal").
#
# Usage: tt-launch SESSION
set -euo pipefail

# Always-on trace. Lives at ~/.cache/tt-launch/last-launch.trace on the remote.
TRACE_DIR="$HOME/.cache/tt-launch"
mkdir -p "$TRACE_DIR"
exec 9>"$TRACE_DIR/last-launch.trace"
BASH_XTRACEFD=9
PS4='+ [$(date +%H:%M:%S)] ${BASH_SOURCE##*/}:${LINENO}: '
set -x

# Validate session name (defense in depth — already checked host-side).
SESSION="${1:?missing session name}"
case "$SESSION" in
  -*) echo "tt-launch: session must not start with '-'" >&2; exit 2 ;;
esac
printf '%s' "$SESSION" | grep -Eq '^[A-Za-z0-9._-]{1,64}$' \
  || { echo "tt-launch: invalid session name" >&2; exit 2; }

# Explicit env activation — login bash on Rocky 8 doesn't source .bashrc, and
# micromamba activation lives in .bashrc on these hosts. Source the usual
# startup files so PATH picks up ~/.local/bin (sesh, micromamba).
#
# Relax strictness around the sources: distros' rc files routinely reference
# unset variables ($HISTCONTROL, $PS1, …) which trip `set -u`, and they use
# pipelines that may legitimately have non-zero exits ($pipefail). Restore
# the strict mode afterwards.
set +euo pipefail
[ -r /etc/profile ] && . /etc/profile
[ -r "$HOME/.profile" ] && . "$HOME/.profile"
[ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc"
set -euo pipefail

# If a sourced rc auto-attached ble.sh (Bash Line Editor), detach it before
# exec'ing tmux. ble-attach hooks DEBUG / PROMPT_COMMAND and reconfigures
# stdin; left attached, the exec below fails with "open terminal failed:
# not a terminal".
if [ -n "${BLE_VERSION-}" ]; then
  ble-detach 2>/dev/null || true
  unset BLE_VERSION
fi

# Micromamba activation (no-op if absent). Activates the `dotfiles` env if
# present so tmux/sesh from that env land on PATH.
if [ -x "$HOME/.local/bin/micromamba" ]; then
  export MAMBA_EXE="$HOME/.local/bin/micromamba"
  export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-$HOME/.local/micromamba}"
  eval "$("$MAMBA_EXE" shell hook --shell bash)"
  [ -d "$MAMBA_ROOT_PREFIX/envs/dotfiles" ] && micromamba activate dotfiles
fi

export TT_HOST_ALIAS="${TT_HOST_ALIAS:-${HOSTNAME%%.*}}"

# tmux must be on PATH.
command -v tmux >/dev/null || { echo "tt-launch: tmux not on PATH" >&2; exit 3; }

# 2-tier attach ladder:
#   1. sesh connect — handles existing-tmux (prefix match) AND zoxide-path create
#   2. fallback: tmux new-session -As — for genuinely-new sessions sesh doesn't know
#
# Do NOT `exec sesh ... || true` — exec replaces the shell, so the fallback is
# unreachable when sesh exits non-zero. Run sesh, exit on success, otherwise
# fall through.
if command -v sesh >/dev/null 2>&1; then
  if sesh connect "$SESSION"; then
    exit 0
  fi
fi
exec tmux new-session -As "$SESSION"
