#!/bin/sh
# tt-osc52-copy — OSC 52 clipboard helper for tmux.
#
# tmux's built-in `set-clipboard on` path goes through the terminfo Ms
# capability. Two problems with that under our tt flow (mosh -> WT):
#   1. A generic Ms emits `\E]52;%p1%s;%p2%s\7`. mosh 1.4 only forwards the
#      explicit-`c`-target form `\E]52;c;...\7` reliably.
#   2. Even with terminal-overrides forcing the right Ms, already-attached
#      tmux clients keep stale terminal features after a config reload —
#      so the fix only applies to NEW sessions.
#
# This helper sidesteps both. It reads the selection on stdin and writes the
# OSC 52 sequence DIRECTLY to the tmux client's tty.
#
# Usage (from tmux): copy-pipe-and-cancel "tt-osc52-copy"
#
# We tried passing `#{client_tty}` as $1 from the bind via `send -FX`. That
# does not work: `-F` expands the KEYS argument to send-keys, not the command
# string passed to copy-pipe-and-cancel. Result: $1 was always empty. We now
# resolve the client tty from inside the helper via `tmux display -p`.

tty=$1

# If caller didn't pass a tty, ask tmux. Picks the first attached client of
# whatever pane invoked us — which is exactly the client that copied.
if [ -z "$tty" ] && command -v tmux >/dev/null 2>&1 && [ -n "${TMUX:-}" ]; then
  tty=$(tmux display -p '#{client_tty}' 2>/dev/null)
fi

if [ -z "$tty" ] || [ ! -w "$tty" ]; then
  exit 0
fi

{
  printf '\033]52;c;'
  base64 | tr -d '\n'
  printf '\007'
} > "$tty"
