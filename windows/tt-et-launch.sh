#!/usr/bin/env bash
# tt-et-launch HOST SESSION B64
# WSL-side wrapper. Bootstraps etserver on HOST via SSH (idempotent), then
# `et`'s with a reverse tunnel for URL forwarding and runs the base64-encoded
# tt-launch helper to attach the tmux session.
#
# Deployed by bootstrap.sh as ~/.local/bin/tt-et-launch (WSL). tt.ps1 and
# tt.zsh both call this; keeps the Win-side argv flat and the et plumbing
# in one place.
set -euo pipefail

host="${1:?usage: tt-et-launch HOST SESSION B64}"
session="${2:?usage: tt-et-launch HOST SESSION B64}"
b64="${3:?usage: tt-et-launch HOST SESSION B64}"

ET_PORT="${TT_ET_PORT:-2022}"
OPEN_PORT="${TT_OPEN_PORT:-8765}"

# Validate session name — keeps the inner single-quote bash arg safe and stops
# anything that could leak past our quoting.
case "$session" in
  -*) echo "tt-et-launch: session must not start with '-'" >&2; exit 2 ;;
esac
[[ "$session" =~ ^[A-Za-z0-9._-]{1,64}$ ]] \
  || { echo "tt-et-launch: invalid session name '$session'" >&2; exit 2; }

# 1. Start the local URL-bridge listener (idempotent — self-checks port).
#    ET runs in WSL, so the -rt tunnel's destination is WSL's localhost; the
#    listener has to be here, not on the Windows host. The listener invokes
#    `cmd.exe /c start <url>` to open the URL in the default Windows browser.
#    bootstrap.sh installs ~/.local/bin/tt-listener as a symlink to the .py.
if command -v tt-listener >/dev/null 2>&1; then
  # Cheap port probe — anything already listening on $OPEN_PORT counts.
  if ! (exec 3<>/dev/tcp/127.0.0.1/"$OPEN_PORT") 2>/dev/null; then
    TT_OPEN_PORT="$OPEN_PORT" nohup tt-listener \
      >/tmp/tt-listener.log 2>&1 < /dev/null &
    disown 2>/dev/null || true
    sleep 0.2
  else
    exec 3<&- 2>/dev/null
  fi
fi

# 2. Make sure etserver is running on the remote. SSH is fast enough (existing
#    ControlPersist on the user's ssh-config keeps this near-instant after the
#    first hit), and starting etserver via SSH is the cleanest no-sudo
#    bootstrap on these hosts.
#    NOTE: we don't pass --daemon — that flag tries to write /var/run/etserver.pid
#    which is root-only on Rocky 8. Plain `nohup ... &` plus stdio redirection
#    detaches just as well.
ssh -o ConnectTimeout=10 "$host" "bash -lc '\
  pgrep -u \$USER etserver >/dev/null \
  || nohup ~/.local/bin/etserver --port $ET_PORT >/tmp/etserver.log 2>&1 < /dev/null & \
  sleep 0.4'" || {
    echo "tt-et-launch: could not start etserver on $host" >&2
    exit 1
}

# 2. Build the remote shell payload (mirrors tt.ps1 / tt.zsh).
#    - TT_HOST_ALIAS so tmux titles render the alias not the container hostname
#    - BROWSER=tt-open so xdg-open / python webbrowser / etc. POST to our
#      Windows-side listener via the et -rt tunnel below
#    - decode b64 -> ~/.local/bin/tt-launch -> exec bash <file> SESSION
inner="export TT_HOST_ALIAS='$host' \
&& export BROWSER=tt-open \
&& export TT_OPEN_PORT='$OPEN_PORT' \
&& mkdir -p ~/.local/bin \
&& echo $b64 | base64 -d > ~/.local/bin/tt-launch \
&& chmod 0755 ~/.local/bin/tt-launch \
&& exec bash ~/.local/bin/tt-launch '$session'"

# 3. et with reverse tunnel: remote port OPEN_PORT -> local Windows-side
#    listener (via WSL localhost forwarding, which Windows treats as 127.0.0.1).
#    -c runs the inner command instead of an interactive shell.
exec et "${host}:${ET_PORT}" \
  -rt "${OPEN_PORT}:127.0.0.1:${OPEN_PORT}" \
  -c "$inner"
