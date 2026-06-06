#!/usr/bin/env bash
# tt-wezterm-session HOST SESSION
#
# Entry command for tt-launched WezTerm mux panes. It replaces the old
# sesh/tmux attach helper: a WezTerm workspace is the durable session boundary.
set -euo pipefail

host="${1:?usage: tt-wezterm-session HOST SESSION}"
session="${2:?usage: tt-wezterm-session HOST SESSION}"

case "$host" in
  -*) echo "tt-wezterm-session: host must not start with '-'" >&2; exit 2 ;;
esac
case "$session" in
  -*) echo "tt-wezterm-session: session must not start with '-'" >&2; exit 2 ;;
esac
[[ "$host" =~ ^[A-Za-z0-9._-]{1,64}$ ]] \
  || { echo "tt-wezterm-session: invalid host '$host'" >&2; exit 2; }
[[ "$session" =~ ^[A-Za-z0-9._-]{1,64}$ ]] \
  || { echo "tt-wezterm-session: invalid session '$session'" >&2; exit 2; }

export TT_HOST_ALIAS="$host"
export TT_SESSION="$session"
export WEZTERM_WORKSPACE="${host}:${session}"

for d in "$HOME/.local/bin" "$HOME/.local/share/mise/shims" "$HOME/.local/micromamba/envs/dotfiles/bin"; do
  case ":${PATH:-}:" in
    *":$d:"*) ;;
    *) [ -d "$d" ] && PATH="$d${PATH:+:$PATH}" ;;
  esac
done
export PATH

printf '\033]0;%s:%s\007' "$host" "$session"

if command -v zoxide >/dev/null 2>&1; then
  if target="$(zoxide query "$session" 2>/dev/null)" && [ -n "$target" ]; then
    cd "$target"
  fi
fi

if command -v zsh >/dev/null 2>&1; then
  exec zsh -l
fi

exec "${SHELL:-/bin/bash}" -l
