# dotfiles

Portable dev environment for any Linux host (Rocky 8 with no sudo, Ubuntu,
macOS, WSL). Mirrors Adarsh's BAN setup: zsh + oh-my-zsh + Powerlevel10k,
tmux + oh-my-tmux, sesh, zoxide, fzf, mise.

## One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/advarshney/dotfiles/main/bootstrap.sh | bash
exec zsh -l
```

## What bootstrap does

1. Clones this repo to `~/repos/dotfiles`.
2. Installs missing tools:
   - **sudo + apt/dnf available** → system install of `git curl tmux zsh mosh`.
   - **no sudo** → falls back to userland `micromamba` env at `~/.local/micromamba/envs/dotfiles/`.
3. Drops single-binary userland tools into `~/.local/bin`: `mise`, `zoxide`, `fzf`, `sesh`.
4. Installs **oh-my-zsh** + custom plugins (`zsh-autosuggestions`, `zsh-syntax-highlighting`) + **Powerlevel10k**.
5. Clones **oh-my-tmux** (`gpakosz/.tmux`) and symlinks `~/.tmux.conf` to its upstream file.
6. Runs `link.sh`, which symlinks every file under `zsh/`, `tmux/`, `sesh/`, `git/`, `mise/` into `$HOME`, preserving directory structure.
7. Clones the **private** secrets repo `advarshney/dotfiles-secrets` to `~/.config/dotfiles-secrets/` (requires SSH-agent access).
8. Adds an idempotent `@import` line to `~/.claude/CLAUDE.md` pointing at `claude/CLAUDE.md` so every Claude session knows to edit *this* repo, not the live files.
9. `mise install` to materialize pinned tools (e.g. `bun`).

## Layout

```
dotfiles/
├── bootstrap.sh                installer (sudo-optional, idempotent)
├── link.sh                     symlinks each package into $HOME
├── README.md
├── zsh/
│   ├── .zshrc                  portable; host-specific dirs guarded with [[ -d ... ]]
│   ├── .zshenv                 PATH + env for all zsh invocations
│   ├── .aliases                sourced from .zshrc
│   ├── .p10k.zsh               Powerlevel10k user config
│   └── .zsh/completions/       runtime-generated sesh completion etc.
├── tmux/
│   └── .tmux.conf.local        oh-my-tmux overrides (upstream .tmux.conf is symlinked)
├── sesh/.config/sesh/sesh.toml
├── git/
│   ├── .gitconfig
│   └── .gitignore_global
├── mise/.config/mise/config.toml
├── claude/CLAUDE.md            the dotfiles-workflow rule, imported into global ~/.claude/CLAUDE.md
└── docs/
    ├── secrets.md              how the private dotfiles-secrets repo works
    └── wsl-windows-terminal.md mosh client + WT profiles (Phase 2)
```

## Editing rule

**Don't edit `~/.zshrc` directly. Edit `~/repos/dotfiles/zsh/.zshrc` and push.**

After bootstrap, that rule is enforced by the global Claude rule in
`claude/CLAUDE.md` — Claude will route edits through the repo automatically.

```bash
cd ~/repos/dotfiles
$EDITOR zsh/.zshrc
git diff
git commit -am "your message"
git push

# On every host that needs the change:
cd ~/repos/dotfiles && git pull && ./link.sh && exec zsh -l
```

## Secrets

API keys and tokens live in a separate **private** repo,
`advarshney/dotfiles-secrets`, cloned at `~/.config/dotfiles-secrets/`. The
committed `.zshrc` sources `secrets.zsh` from there if present. See
`docs/secrets.md`.

## SSH auth across hosts

`Host *` in your `~/.ssh/config` already has `ForwardAgent yes`. As long as
your Windows ssh-agent has your GitHub SSH key loaded (one-time:
`Get-Service ssh-agent | Set-Service -StartupType Automatic; Start-Service ssh-agent; ssh-add`),
both repos (public and private) clone over SSH from BAN/SC without per-host
token setup.

## Per-host overrides

If a host needs config that doesn't belong in git (one-off env, machine-specific
path), drop it in `~/.zshrc.local`. The committed `.zshrc` sources it last.
