# Per-machine-safe exports. Anything truly host-specific lives in ~/.zshrc.local
# (not tracked) and is sourced at the end of this file.

export GPG_TTY="$(tty 2>/dev/null || true)"

# Color-friendly less
export LESSOPEN="| /usr/bin/env -S highlight --quiet --force --inline-css --syntax-by-name=text %s 2>/dev/null"
export LESSCOLORIZER="highlight"

# Less search highlight off by default (noisy on long files)
export LESS="${LESS:--FRXSi}"

# Tell tools we're in a fancy terminal.
[[ "$TERM" == "xterm" || -z "$TERM" ]] && export TERM=xterm-256color

# Host-local overrides (not in git).
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
