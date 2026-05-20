#!/usr/bin/env bash
# tt-open — POST a URL to the Windows-side listener over ET's reverse tunnel.
# Deployed by bootstrap.sh as ~/.local/bin/tt-open on every host.
# Used as $BROWSER so `xdg-open`, `python -m webbrowser`, etc. on the remote
# pop the URL in the local Windows default browser.
#
# Listener (Windows side) lives at http://127.0.0.1:${TT_OPEN_PORT:-8765}.
# Inside an et session, that port is reverse-tunneled to the same port on
# Windows; outside (plain ssh, mosh) the curl fails fast and we just print.
url="${1:-}"
[ -z "$url" ] && { echo "tt-open: missing URL" >&2; exit 1; }
port="${TT_OPEN_PORT:-8765}"
curl -fsS --max-time 2 -X POST "http://127.0.0.1:${port}/" --data-binary "$url" >/dev/null 2>&1 \
  && exit 0
# Fallback: just print so the user can copy/paste.
echo "tt-open: no listener on :${port} (URL was: $url)" >&2
exit 1
