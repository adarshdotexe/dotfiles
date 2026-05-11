# Dotfiles workflow — global Claude rule

This file is sourced into Adarsh's global `~/.claude/CLAUDE.md` via an
`@import` line that `bootstrap.sh` adds idempotently.

## Rule: edit dotfiles, not the live home directory

When the user asks for ANY change to a shell, prompt, multiplexer, git, or
runtime-manager config, **edit the source file inside `~/repos/dotfiles/`**,
not the symlinked copy under `$HOME`.

### Mapping

| Live file in $HOME              | Source in ~/repos/dotfiles/             |
|---------------------------------|------------------------------------------|
| `~/.zshrc`                      | `zsh/.zshrc`                             |
| `~/.zshenv`                     | `zsh/.zshenv`                            |
| `~/.aliases`                    | `zsh/.aliases`                           |
| `~/.p10k.zsh`                   | `zsh/.p10k.zsh`                          |
| `~/.tmux.conf.local`            | `tmux/.tmux.conf.local`                  |
| `~/.gitconfig`                  | `git/.gitconfig`                         |
| `~/.gitignore_global`           | `git/.gitignore_global`                  |
| `~/.config/sesh/sesh.toml`      | `sesh/.config/sesh/sesh.toml`            |
| `~/.config/mise/config.toml`    | `mise/.config/mise/config.toml`          |

**Do NOT edit `~/.tmux.conf`** — that is the upstream `gpakosz/.tmux` file,
not a user config. User overrides go in `~/.tmux.conf.local` (mapped above).

### Hands-off paths

The following live in `$HOME` but are NOT mirrored from the dotfiles repo. Edit
them directly:

- `~/.ssh/config`, `~/.ssh/*` — host-private, never commit
- `~/.zshrc.local` — host-local overrides
- `~/.config/dotfiles-secrets/secrets.zsh` — secrets repo (separate private repo)
- `~/.histfile`, `~/.viminfo`, `~/.python_history` — runtime state

### After editing

Remind the user how to propagate the change:

```bash
cd ~/repos/dotfiles
git diff
git add -p && git commit -m "<message>"
git push

# On each host that needs the change:
cd ~/repos/dotfiles && git pull && ./link.sh && exec zsh -l
```

If the change is host-specific (only applies on BAN, only on WSL, etc.),
wrap it with a guard inside the dotfiles file itself — e.g.
`[[ -d /home/scratch.advarshney_gpu ]] && ...` — so the single committed file
keeps working on every other host.

### Secrets

Anything that looks like an API key, token, or credential (`*_API_KEY`,
`*_TOKEN`, `GITHUB_TOKEN`, `GITLAB_TOKEN`, `ANTHROPIC_API_KEY`, etc.) **never**
goes into `~/repos/dotfiles/`. Direct the user to put it in the private
`adarshdotexe/dotfiles-secrets` repo, cloned at `~/.config/dotfiles-secrets/`.
