# Phase 2: WSL + Windows Terminal + Mosh

Phase 1 (bootstrap.sh) gives you a working environment on any host you SSH into.
Phase 2 makes the *client* side resilient and unified: all your hosts as tabs in
one Windows Terminal, each connected with mosh so they survive sleep/roam/wifi
changes.

## 1. Install mosh in WSL

```bash
sudo apt update && sudo apt install -y mosh
mosh --version    # confirm
```

(Or run `~/repos/dotfiles/bootstrap.sh` in WSL too — same config everywhere.)

## 2. Share your Windows SSH agent with WSL

So `git push`/`git clone` and `ssh BAN` from WSL use the keys already loaded in
the Windows `ssh-agent` (which is also what your forwarded-agent SSH config
depends on for cloning dotfiles on BAN/SC/etc.).

**Option A — simplest: copy keys into WSL once.** Acceptable for personal
machines where WSL is trusted.

```bash
cp -r /mnt/c/Users/advarshney/.ssh ~/.ssh
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_* ~/.ssh/config 2>/dev/null
```

**Option B — proper agent sharing via `wsl2-ssh-agent`** (no key duplication):

```bash
# In WSL, one-time install:
curl -fsSL https://github.com/mame/wsl2-ssh-agent/releases/latest/download/wsl2-ssh-agent \
  -o ~/.local/bin/wsl2-ssh-agent
chmod +x ~/.local/bin/wsl2-ssh-agent

# Add to your WSL ~/.zshrc (or have dotfiles handle it):
eval "$(~/.local/bin/wsl2-ssh-agent)"
```

This relays the Windows ssh-agent over npiperelay so `ssh-add -l` from WSL shows
the same keys as Windows.

**Option C — 1Password SSH agent** if you use 1Password: enable the SSH agent in
1Password settings, set `IdentityAgent` in your WSL `~/.ssh/config`. Cleanest if
1Password is already in your stack.

## 3. Generate Windows Terminal profiles

Open Windows Terminal settings (`Ctrl+,`), pick "Open JSON file", and add the
following entries inside the top-level `"profiles"."list"` array. Generate fresh
GUIDs (e.g. `[guid]::NewGuid()` in PowerShell, or any online UUIDv4 generator).

```jsonc
{
  "name": "BAN (claude)",
  "guid": "{REPLACE-ME-UUID}",
  "commandline": "wsl.exe --cd ~ -- mosh BAN -- tmux new -A -s main",
  "icon": "ms-appx:///ProfileIcons/{9acb9455-ca41-5af7-950f-6bca1bc9722f}.png",
  "tabTitle": "BAN",
  "colorScheme": "One Half Dark",
  "font": { "face": "CascadiaCode NF", "size": 11 }
},
{
  "name": "SC (claude)",
  "guid": "{REPLACE-ME-UUID}",
  "commandline": "wsl.exe --cd ~ -- mosh SC -- tmux new -A -s main",
  "icon": "ms-appx:///ProfileIcons/{9acb9455-ca41-5af7-950f-6bca1bc9722f}.png",
  "tabTitle": "SC",
  "colorScheme": "One Half Dark"
},
{
  "name": "H100",
  "guid": "{REPLACE-ME-UUID}",
  "commandline": "wsl.exe --cd ~ -- mosh H100 -- tmux new -A -s main"
},
{
  "name": "GB100",
  "guid": "{REPLACE-ME-UUID}",
  "commandline": "wsl.exe --cd ~ -- mosh GB100 -- tmux new -A -s main"
},
{
  "name": "PACE",
  "guid": "{REPLACE-ME-UUID}",
  "commandline": "wsl.exe --cd ~ -- mosh PACE -- tmux new -A -s main"
},
{
  "name": "FRAPPE",
  "guid": "{REPLACE-ME-UUID}",
  "commandline": "wsl.exe --cd ~ -- mosh FRAPPE -- tmux new -A -s main"
},
{
  "name": "VFDB",
  "guid": "{REPLACE-ME-UUID}",
  "commandline": "wsl.exe --cd ~ -- mosh VFDB -- tmux new -A -s main"
}
```

Optionally bind tab-open shortcuts in the same `settings.json` `"actions"`:

```jsonc
{ "command": { "action": "newTab", "profile": "BAN (claude)" },  "keys": "ctrl+shift+1" },
{ "command": { "action": "newTab", "profile": "SC (claude)"  },  "keys": "ctrl+shift+2" },
{ "command": { "action": "newTab", "profile": "H100"         },  "keys": "ctrl+shift+3" },
{ "command": { "action": "newTab", "profile": "GB100"        },  "keys": "ctrl+shift+4" }
```

## 4. Make mosh work through corporate firewalls

Mosh uses UDP ports 60000–61000 by default. If a host is behind a firewall that
blocks those, restrict the range and ask netsec to open it:

```bash
# On the remote (or in your dotfiles), wrap mosh-server:
mosh --server="mosh-server new -p 60001:60010" BAN
```

If UDP is fully blocked, fall back to plain SSH+tmux for that host — same `tmux
new -A -s main` semantics work the same, just without auto-reconnect:

```jsonc
{
  "name": "BAN (ssh fallback)",
  "guid": "{REPLACE-ME-UUID}",
  "commandline": "wsl.exe --cd ~ -- ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -t BAN tmux new -A -s main"
}
```

## 5. Daily usage

- `Ctrl+Shift+T` to pick a host profile from the WT dropdown (or use the
  bound shortcuts above).
- Inside any session, `Ctrl+Space K` (your tmux prefix + K) → sesh picker →
  jump to any project session.
- If your laptop sleeps, the wifi drops, or you roam networks, the WT tab
  shows `mosh: reconnecting…` briefly and then everything continues — Claude
  Code keeps its state because tmux on the remote never died.

## 6. SSH config — keep it in sync across machines (optional)

`~/.ssh/config` is host-specific (contains internal NVIDIA hostnames). Don't
add it to the public dotfiles repo. Two reasonable options:

- Keep it in a *private* gist/gitlab repo and clone it separately on each host.
- Or just maintain it by hand on each Windows + WSL pair; it changes rarely.
