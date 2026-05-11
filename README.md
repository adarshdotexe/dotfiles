# dotfiles

Portable dev environment for any Linux host (Rocky 8, Ubuntu, WSL, etc.), with or without sudo.

## One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/advarshney/dotfiles/main/bootstrap.sh | bash
```

Then:

```bash
exec zsh -l
```

## What you get

| Tool | Purpose |
|---|---|
| `zsh` + oh-my-zsh + autosuggestions + syntax-highlighting + fzf-tab | shell |
| `starship` | prompt |
| `tmux` (>=3.2) | terminal multiplexer |
| `sesh` | tmux session manager (zoxide + ssh hosts + configured projects) |
| `zoxide` | smarter `cd` |
| `mosh` | resilient SSH |
| `mise` | manages `node`, `bun`, `deno`, `python`, `uv` |
| `fzf` | fuzzy finder used by everything |

## How it works on no-sudo hosts (BAN, SC, etc.)

The bootstrap detects whether `sudo` is available. If not:

- `mosh-server`, `tmux` (when system version is too old), and `zsh` (when missing) are installed into a userland `micromamba` env at `~/.local/micromamba/envs/dotfiles/bin`
- All other tools land in `~/.local/bin/`
- Nothing is written outside `$HOME`

## Authenticating on new hosts

Your SSH config already has `ForwardAgent yes` on `Host *`. As long as your local
`ssh-agent` has your GitHub key loaded, `git clone` and `git push` over SSH "just
work" on BAN, SC, and anywhere else you reach via your ssh config.

Local one-time setup on Windows:

```powershell
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent
ssh-add $env:USERPROFILE\.ssh\id_ed25519     # or whichever key you use for GitHub
```

For WSL, see `docs/wsl-windows-terminal.md`.

## Layout

```
dotfiles/
├── bootstrap.sh                  one-shot installer (idempotent)
├── link.sh                       symlinks each subdir into $HOME
├── zsh/                          .zshrc, .zshenv, .zsh/*.zsh fragments
├── tmux/                         .tmux.conf
├── sesh/                         .config/sesh/sesh.toml
├── git/                          .gitconfig, .gitignore_global
├── mise/                         .config/mise/config.toml
├── starship/                     .config/starship.toml
└── docs/                         phase-2 / WSL / Windows Terminal notes
```

To add a tool: create a new top-level dir matching the layout under `$HOME`, add
its name to the `PKGS` list in `link.sh`, commit.

## Updating an installed host

```bash
cd ~/repos/dotfiles && git pull && ./link.sh
```

Or just rerun the one-liner — `bootstrap.sh` is idempotent.
