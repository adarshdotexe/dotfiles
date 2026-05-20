#!/usr/bin/env python3
"""Replace the embedded base64 constant in tt.ps1 and tt.zsh with the
freshly-generated value from tt-launch.b64."""
import pathlib
import sys

ROOT = pathlib.Path("/mnt/c/Users/advarshney/repos/dotfiles")
b64 = (ROOT / "windows/tt-launch.b64").read_text().strip()
print(f"b64 length: {len(b64)}")

targets = [
    (ROOT / "windows/tt.ps1", "$script:TtLaunchB64 = ", f"$script:TtLaunchB64 = '{b64}'"),
    (ROOT / "zsh/.zsh/tt.zsh", "_TT_LAUNCH_B64=", f"_TT_LAUNCH_B64='{b64}'"),
]

for path, prefix, new_line in targets:
    text = path.read_text()
    lines = text.splitlines()
    out = []
    replaced = False
    for line in lines:
        if not replaced and line.startswith(prefix):
            out.append(new_line)
            replaced = True
        else:
            out.append(line)
    if not replaced:
        sys.exit(f"FAIL: prefix not found in {path}")
    # Preserve trailing newline.
    suffix = "\n" if text.endswith("\n") else ""
    path.write_text("\n".join(out) + suffix)
    print(f"updated {path}")
