#!/usr/bin/env bash
# tt-et-launch HOST SESSION
# WSL-side wrapper. Bootstraps etserver on HOST via SSH (idempotent), spawns
# the local URL-bridge listener if needed, then et's with a reverse tunnel.
#
# Deployed by bootstrap.sh as ~/.local/bin/tt-et-launch (WSL). tt.ps1 and
# tt.zsh both call this — keeps the Win-side argv flat and the et plumbing
# in one place.
#
# tt-launch is also bootstrap-deployed on the remote, so the et command we
# invoke is just `bash -lc 'TT_HOST_ALIAS=HOST tt-launch SESSION'` — short
# enough for ET's `-c` to type cleanly into the remote's login shell (csh
# on BAN/SC/UFLWPE), no base64 / eval gymnastics.
set -euo pipefail

host="${1:?usage: tt-et-launch HOST SESSION}"
session="${2:?usage: tt-et-launch HOST SESSION}"

ET_PORT="${TT_ET_PORT:-2022}"
OPEN_PORT="${TT_OPEN_PORT:-8765}"

# Validate session name — keeps the inner bash arg safe and stops anything
# that could leak through quoting.
case "$session" in
  -*) echo "tt-et-launch: session must not start with '-'" >&2; exit 2 ;;
esac
[[ "$session" =~ ^[A-Za-z0-9._-]{1,64}$ ]] \
  || { echo "tt-et-launch: invalid session name '$session'" >&2; exit 2; }

# 1. Start the local URL-bridge listener (idempotent — self-checks port).
#    ET runs in WSL, so the -r tunnel's destination is WSL's localhost; the
#    listener has to be here, not on the Windows host. It invokes
#    `cmd.exe /c start <url>` to open URLs in the default Windows browser.
if command -v tt-listener >/dev/null 2>&1; then
  if ! (exec 3<>/dev/tcp/127.0.0.1/"$OPEN_PORT") 2>/dev/null; then
    TT_OPEN_PORT="$OPEN_PORT" nohup tt-listener \
      >/tmp/tt-listener.log 2>&1 < /dev/null &
    disown 2>/dev/null || true
    sleep 0.2
  else
    exec 3<&- 2>/dev/null
  fi
fi

# 2. Make sure etserver is running on the remote. SSH is fast enough — and
#    starting via SSH is the cleanest no-sudo bootstrap on these hosts.
#    NOTE: we don't pass --daemon — that wants /var/run/etserver.pid which
#    is root-only. nohup + stdio redirection detaches just as well.
ssh -o ConnectTimeout=10 "$host" "bash -lc '\
  pgrep -u \$USER etserver >/dev/null \
  || nohup ~/.local/bin/etserver --port $ET_PORT >/tmp/etserver.log 2>&1 < /dev/null & \
  sleep 0.4'" || {
    echo "tt-et-launch: could not start etserver on $host" >&2
    exit 1
}

# 3. et with reverse tunnel + short remote command. ET's `-c` arg gets typed
#    into the user's remote login shell (csh on BAN/SC/UFLWPE), so we keep
#    the command short and csh-safe by deferring everything to
#    ~/.local/bin/tt-launch (deployed by bootstrap on the remote).
#    Tunnel syntax is `srcPort:dstPort` (NOT ssh-style src:host:dst), and
#    we use `-r` (not `-rt`, which ET 6.2.11 misparses as `-r t…`).
exec et "${host}:${ET_PORT}" \
  -r "${OPEN_PORT}:${OPEN_PORT}" \
  -c "bash -lc 'TT_HOST_ALIAS=$host tt-launch $session'"
