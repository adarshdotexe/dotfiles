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
# OSC 52 sequence DIRECTLY to the tmux client's tty. Wired in via tmux's
# copy-pipe-and-cancel; the bind passes #{client_tty} expanded at copy time
# (send -FX), so each invocation targets the right client.
#
# Usage (from tmux): copy-pipe-and-cancel "tt-osc52-copy '#{client_tty}'"

tty=$1

if [ -z "$tty" ] || [ ! -w "$tty" ]; then
  exit 0
fi

{
  printf '\033]52;c;'
  base64 | tr -d '\n'
  printf '\007'
} > "$tty"
