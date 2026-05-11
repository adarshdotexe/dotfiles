# Secrets — `advarshney/dotfiles-secrets` (private)

Secrets (API tokens, passwords, anything you don't want public) live in a
separate **private** GitHub repo, cloned by `bootstrap.sh` to
`~/.config/dotfiles-secrets/`. The committed `~/.zshrc` sources
`~/.config/dotfiles-secrets/secrets.zsh` if it exists.

## Why a second repo and not `.zshrc.local`

- **Sync across hosts via `git pull`** — same workflow as the main repo.
- **History** — you can see when/why a key changed, roll back.
- **Single source of truth** — change a key once, propagate to every host.
- Forward-agent SSH (already on for `Host *`) handles auth on every host.

## One-time setup

1. **Create the private repo on GitHub:**
   ```bash
   gh repo create advarshney/dotfiles-secrets --private --description "Secrets for dotfiles. Never make this public."
   ```

2. **Initialize it locally:**
   ```bash
   mkdir -p ~/.config/dotfiles-secrets
   cd ~/.config/dotfiles-secrets
   git init -b main
   git remote add origin git@github.com:advarshney/dotfiles-secrets.git
   ```

3. **Create `secrets.zsh`:**
   ```bash
   cat > secrets.zsh <<'SECRETS'
   # Secrets — sourced by dotfiles/zsh/.zshrc.
   # NEVER commit this content to a public repo.

   export JIRA_API_TOKEN="..."
   export ANTHROPIC_API_KEY="..."
   export GITLAB_TOKEN="..."
   export CONFLUENCE_API_TOKEN="..."
   # (and any others you collect over time)
   SECRETS
   ```

4. **Add a defensive `.gitignore`:**
   ```bash
   cat > .gitignore <<'GI'
   # Belt-and-suspenders: never commit OS junk into this repo.
   .DS_Store
   *.swp
   GI
   ```

5. **Commit and push:**
   ```bash
   git add secrets.zsh .gitignore
   git commit -m "initial secrets"
   git push -u origin main
   ```

## On every new host

`bootstrap.sh` clones it automatically as long as your SSH agent forwards
your GitHub key (which it does — `ForwardAgent yes` on `Host *`).

If the clone fails:

```bash
git clone git@github.com:advarshney/dotfiles-secrets.git ~/.config/dotfiles-secrets
```

Then `exec zsh -l`.

## Adding a new secret

```bash
cd ~/.config/dotfiles-secrets
$EDITOR secrets.zsh           # add export FOO_TOKEN="..."
git commit -am "add FOO_TOKEN"
git push

# On other hosts:
cd ~/.config/dotfiles-secrets && git pull
```

## Rotating

Same as adding — edit, commit, push, pull on each host. Bonus: `git log` of
the secrets repo doubles as an audit trail of when each key was rotated.

## What absolutely does NOT go in the public dotfiles repo

| Pattern                | Where it goes                  |
|------------------------|--------------------------------|
| `*_API_KEY`            | `secrets.zsh`                  |
| `*_TOKEN`              | `secrets.zsh`                  |
| `ANTHROPIC_API_KEY`    | `secrets.zsh`                  |
| `GITHUB_TOKEN`         | `secrets.zsh`                  |
| `GITLAB_TOKEN`         | `secrets.zsh`                  |
| `AZURE_OPENAI_API_KEY` | `secrets.zsh`                  |
| `OPENAI_API_KEY`       | `secrets.zsh`                  |
| Vault/JWT raw tokens   | `secrets.zsh`                  |
| `JIRA_API_TOKEN`       | `secrets.zsh`                  |
| `CONFLUENCE_API_TOKEN` | `secrets.zsh`                  |
| internal customer info | `~/.zshrc.local` (host-only)   |
