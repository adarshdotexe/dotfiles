#!/usr/bin/env python3
"""tt-listener — WSL-side bridge that pops URLs into the Windows browser.

Started by tt-et-launch.sh on first launch (idempotent — checks the port and
bails if another instance is already listening). Listens on 127.0.0.1:${TT_OPEN_PORT}
which ET reverse-tunnels from the remote, so the remote's `tt-open` POST hits
this process; we then shell out to `cmd.exe /c start <url>` for Windows to open
the URL in the default browser.

The listener lives in WSL (not on Windows) because that's where the ET client
runs — the `-rt 8765:127.0.0.1:8765` tunnel's destination is the ET client's
localhost. Putting the listener in Windows would require WSL2 mirrored-mode
networking, which isn't universal.

Usage:
    tt-listener           # start (foreground; tt-et-launch spawns in background)
    tt-listener --stop    # not implemented; just `pkill -f tt-listener.py`
"""

import http.server
import os
import socket
import subprocess
import sys

PORT = int(os.environ.get("TT_OPEN_PORT", "8765"))


def port_in_use(port: int) -> bool:
    """Return True if something is already listening on 127.0.0.1:port."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(0.5)
    try:
        sock.connect(("127.0.0.1", port))
        return True
    except OSError:
        return False
    finally:
        sock.close()


class Handler(http.server.BaseHTTPRequestHandler):
    # Silence the default per-request stderr log; tt-listener runs in the
    # background and we don't want stray output.
    def log_message(self, fmt, *args):
        pass

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        url = self.rfile.read(length).decode("utf-8", errors="replace").strip()
        # Conservative allowlist: only http(s). The remote side passes a fully-
        # formed URL from $BROWSER; a hostile session could try file:// or
        # other URI handlers, so reject anything we wouldn't want a browser
        # tab to render directly.
        if url.startswith(("http://", "https://")):
            # `cmd.exe /c start "" URL` — the empty "" is the title arg that
            # `start` requires when the first arg looks like a quoted path.
            try:
                subprocess.Popen(
                    ["cmd.exe", "/c", "start", "", url],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                self.send_response(204)
            except Exception:
                self.send_response(500)
        else:
            self.send_response(400)
        self.end_headers()


def main():
    if port_in_use(PORT):
        # Another listener is already running; nothing to do.
        return 0
    with http.server.HTTPServer(("127.0.0.1", PORT), Handler) as srv:
        try:
            srv.serve_forever()
        except KeyboardInterrupt:
            return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
