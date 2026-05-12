#!/usr/bin/env bash
# Portable dev environment bootstrap.
# Works with or without sudo. Idempotent. Designed for Rocky 8 + NVIDIA xterms
# (BAN, SC, ...) and WSL/Ubuntu/macOS.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/adarshdotexe/dotfiles/main/bootstrap.sh | bash
#
# Env overrides:
#   DOTFILES_REPO=https://github.com/adarshdotexe/dotfiles.git
#   DOTFILES_DIR=$HOME/repos/dotfiles
#   SECRETS_REPO=git@github.com:adarshdotexe/dotfiles-secrets.git
#   SECRETS_DIR=$HOME/.config/dotfiles-secrets
#   SKIP_SECRETS=1     # don't try to clone the secrets repo

set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/adarshdotexe/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/repos/dotfiles}"
SECRETS_REPO="${SECRETS_REPO:-git@github.com:adarshdotexe/dotfiles-secrets.git}"
SECRETS_DIR="${SECRETS_DIR:-$HOME/.config/dotfiles-secrets}"
LOCAL_BIN="$HOME/.local/bin"
MAMBA_ROOT="$HOME/.local/micromamba"
MAMBA_ENV="$MAMBA_ROOT/envs/dotfiles"
export PATH="$LOCAL_BIN:$MAMBA_ENV/bin:$PATH"
mkdir -p "$LOCAL_BIN"

c_blue=$'\033[1;34m'; c_yellow=$'\033[1;33m'; c_red=$'\033[1;31m'; c_off=$'\033[0m'
log()  { printf '%s[bootstrap]%s %s\n' "$c_blue"   "$c_off" "$*"; }
warn() { printf '%s[bootstrap]%s %s\n' "$c_yellow" "$c_off" "$*" >&2; }
err()  { printf '%s[bootstrap]%s %s\n' "$c_red"    "$c_off" "$*" >&2; }

has()      { command -v "$1" >/dev/null 2>&1; }
has_sudo() { sudo -n true >/dev/null 2>&1; }

detect_pm() {
  for pm in apt-get dnf yum brew; do
    has "$pm" && { echo "$pm"; return; }
  done
  echo none
}

tmux_ok() {
  local v
  v=$(tmux -V 2>/dev/null | awk '{print $2}') || return 1
  awk -v v="$v" 'BEGIN {
    split(v, a, ".");
    major = a[1] + 0; minor = a[2] + 0;
    exit (major > 3 || (major == 3 && minor >= 2)) ? 0 : 1
  }'
}

# ------------------------------------------------------------------ repo
ensure_repo() {
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    log "Cloning dotfiles -> $DOTFILES_DIR"
    mkdir -p "$(dirname "$DOTFILES_DIR")"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  else
    log "Updating dotfiles in $DOTFILES_DIR"
    git -C "$DOTFILES_DIR" pull --ff-only 2>/dev/null || warn "git pull skipped"
  fi
}

ensure_secrets_repo() {
  [[ "${SKIP_SECRETS:-0}" == "1" ]] && { log "SKIP_SECRETS=1, skipping secrets clone"; return; }
  mkdir -p "$(dirname "$SECRETS_DIR")"

  # If gh is authed and SECRETS_REPO is HTTPS, wire gh as git credential helper
  # so the clone doesn't block waiting for username/password.
  if [[ "$SECRETS_REPO" == https://github.com/* ]] && has gh && gh auth status >/dev/null 2>&1; then
    gh auth setup-git 2>/dev/null || true
  fi

  if [[ ! -d "$SECRETS_DIR/.git" ]]; then
    log "Cloning dotfiles-secrets -> $SECRETS_DIR"
    if ! GIT_TERMINAL_PROMPT=0 git clone "$SECRETS_REPO" "$SECRETS_DIR"; then
      warn "Could not clone secrets repo. Either:"
      warn "  - run 'gh auth login' and re-run bootstrap, or"
      warn "  - clone manually: git clone $SECRETS_REPO $SECRETS_DIR"
    fi
  else
    log "Updating secrets repo"
    GIT_TERMINAL_PROMPT=0 git -C "$SECRETS_DIR" pull --ff-only 2>/dev/null \
      || warn "secrets git pull skipped"
  fi
}

# ------------------------------------------------------------------ system pkgs
install_system_pkgs() {
  local pm="$1"; shift
  case "$pm" in
    apt-get) sudo apt-get update -qq && sudo apt-get install -y "$@" ;;
    dnf|yum) sudo "$pm" install -y -q "$@" ;;
    brew)    brew install "$@" ;;
    *)       return 1 ;;
  esac
}

# ------------------------------------------------------------------ micromamba
install_micromamba() {
  has micromamba && return 0
  log "Installing micromamba -> $LOCAL_BIN/micromamba"
  local arch
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)   arch=linux-64 ;;
    Linux-aarch64)  arch=linux-aarch64 ;;
    Darwin-x86_64)  arch=osx-64 ;;
    Darwin-arm64)   arch=osx-arm64 ;;
    *) err "Unsupported platform: $(uname -s)-$(uname -m)"; return 1 ;;
  esac
  local tmp; tmp=$(mktemp -d)
  curl -fLs "https://micro.mamba.pm/api/micromamba/${arch}/latest" \
    | tar -xj -C "$tmp" bin/micromamba
  mv -f "$tmp/bin/micromamba" "$LOCAL_BIN/micromamba"
  rm -rf "$tmp"
}

mamba_install() {
  install_micromamba
  export MAMBA_ROOT_PREFIX="$MAMBA_ROOT"
  mkdir -p "$MAMBA_ROOT"
  if [[ ! -d "$MAMBA_ENV/conda-meta" ]]; then
    log "micromamba create env: $*"
    "$LOCAL_BIN/micromamba" create -y -p "$MAMBA_ENV" -c conda-forge "$@"
  else
    log "micromamba install: $*"
    "$LOCAL_BIN/micromamba" install -y -p "$MAMBA_ENV" -c conda-forge "$@"
  fi
}

# ------------------------------------------------------------------ oh-my-tmux
install_oh_my_tmux() {
  if [[ -d "$HOME/.tmux" && ! -d "$HOME/.tmux/.git" ]]; then
    local bak="$HOME/.tmux.bootstrap-backup.$(date +%s)"
    warn "Existing $HOME/.tmux is not a git repo; moving to $bak"
    mv "$HOME/.tmux" "$bak"
  fi
  if [[ ! -d "$HOME/.tmux/.git" ]]; then
    log "Installing oh-my-tmux (gpakosz/.tmux)"
    git clone --single-branch https://github.com/gpakosz/.tmux.git "$HOME/.tmux"
  else
    log "Updating oh-my-tmux"
    git -C "$HOME/.tmux" pull --ff-only 2>/dev/null || warn "oh-my-tmux pull skipped"
  fi
  # Upstream provides ~/.tmux/.tmux.conf — symlink to ~/.tmux.conf.
  if [[ ! -L "$HOME/.tmux.conf" || "$(readlink "$HOME/.tmux.conf")" != "$HOME/.tmux/.tmux.conf" ]]; then
    [[ -e "$HOME/.tmux.conf" && ! -L "$HOME/.tmux.conf" ]] && \
      mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.bootstrap-backup.$(date +%s)"
    ln -sfn "$HOME/.tmux/.tmux.conf" "$HOME/.tmux.conf"
  fi
}

install_powerlevel10k() {
  local dst="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  if [[ ! -d "$dst/.git" ]]; then
    log "Installing powerlevel10k theme"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$dst"
  else
    log "Updating powerlevel10k"
    git -C "$dst" pull --ff-only 2>/dev/null || warn "p10k pull skipped"
  fi
}

# ------------------------------------------------------------------ bash secrets
# secrets.zsh content is plain POSIX `export X="Y"` — works in bash too.
# This appends a guarded source line to ~/.bashrc and ~/.profile (idempotent)
# so bash login + interactive shells also get ANTHROPIC_API_KEY etc.
wire_bash_secrets() {
  local marker='# dotfiles-secrets: source for bash'
  local line='[ -r "$HOME/.config/dotfiles-secrets/secrets.zsh" ] && . "$HOME/.config/dotfiles-secrets/secrets.zsh"'
  local rc
  for rc in "$HOME/.bashrc" "$HOME/.profile"; do
    [[ -e "$rc" ]] || continue
    if ! grep -qF "$marker" "$rc" 2>/dev/null; then
      log "Adding secrets source to $rc"
      printf '\n%s\n%s\n' "$marker" "$line" >> "$rc"
    fi
  done
}

# ------------------------------------------------------------------ claude rule
wire_claude_rule() {
  local claude_md="$HOME/.claude/CLAUDE.md"
  local import_line="@$DOTFILES_DIR/claude/CLAUDE.md"
  mkdir -p "$HOME/.claude"
  touch "$claude_md"
  if ! grep -qxF "$import_line" "$claude_md"; then
    log "Adding dotfiles @import to $claude_md"
    printf '\n# === dotfiles workflow rule (managed by bootstrap.sh) ===\n%s\n' "$import_line" >> "$claude_md"
  fi
}

# ------------------------------------------------------------------ go

ensure_repo

# Stage 1: try system install where possible.
PM=$(detect_pm)
WANT_SYS=(git curl tmux zsh mosh)
if has_sudo && [[ "$PM" != "none" ]]; then
  missing=()
  for p in "${WANT_SYS[@]}"; do has "$p" || missing+=("$p"); done
  if (( ${#missing[@]} > 0 )); then
    log "sudo + $PM available; installing: ${missing[*]}"
    install_system_pkgs "$PM" "${missing[@]}" || warn "system install partially failed"
  fi
fi

# Stage 2: anything still missing -> micromamba (userland).
MAMBA_NEED=()
has mosh-server || MAMBA_NEED+=(mosh)
tmux_ok        || MAMBA_NEED+=(tmux)
has zsh        || MAMBA_NEED+=(zsh)
if (( ${#MAMBA_NEED[@]} > 0 )); then
  mamba_install "${MAMBA_NEED[@]}"
fi

# Stage 3: single-binary userland tools.
if ! has mise; then
  log "Installing mise"
  curl -fsSL https://mise.run | MISE_INSTALL_PATH="$LOCAL_BIN/mise" sh
fi
if ! has zoxide; then
  log "Installing zoxide"
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh \
    | bash -s -- --bin-dir "$LOCAL_BIN"
fi
if ! has fzf; then
  log "Installing fzf"
  rm -rf "$HOME/.fzf"
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --bin --no-update-rc >/dev/null
  ln -sf "$HOME/.fzf/bin/fzf" "$LOCAL_BIN/fzf"
fi
if ! has sesh; then
  log "Installing sesh"
  case "$(uname -m)" in
    x86_64)        SA=x86_64 ;;
    aarch64|arm64) SA=arm64 ;;
    *)             SA=$(uname -m) ;;
  esac
  # Download then extract — avoids a quirk where filtered tar closes the pipe early.
  tmp=$(mktemp -d)
  if curl -fsSL "https://github.com/joshmedeski/sesh/releases/latest/download/sesh_Linux_${SA}.tar.gz" \
       -o "$tmp/sesh.tar.gz" \
     && tar -xzf "$tmp/sesh.tar.gz" -C "$tmp" \
     && [[ -f "$tmp/sesh" ]]; then
    install -m 0755 "$tmp/sesh" "$LOCAL_BIN/sesh"
  else
    warn "sesh install failed; grab the binary from https://github.com/joshmedeski/sesh/releases"
  fi
  rm -rf "$tmp"
fi

# Stage 4: oh-my-zsh + plugins + powerlevel10k.
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log "Installing oh-my-zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended
fi
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
clone_omz_plugin() {
  local repo="$1" dest="$2"
  [[ -d "$dest/.git" ]] || git clone --depth 1 "https://github.com/$repo.git" "$dest"
}
clone_omz_plugin zsh-users/zsh-autosuggestions     "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_omz_plugin zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
install_powerlevel10k

# Stage 5: oh-my-tmux upstream (~/.tmux + ~/.tmux.conf symlink).
install_oh_my_tmux

# Stage 6: link committed configs into $HOME (.zshrc, .zshenv, .aliases,
# .p10k.zsh, .tmux.conf.local, .gitconfig, mise/sesh under ~/.config/).
log "Linking configs"
bash "$DOTFILES_DIR/link.sh"

# Stage 7: secrets repo (after link, so .zshrc is ready to source it).
ensure_secrets_repo

# Stage 8a: also make bash see ANTHROPIC_API_KEY etc.
wire_bash_secrets

# Stage 8: wire the dotfiles Claude rule into global ~/.claude/CLAUDE.md.
wire_claude_rule

# Stage 9: mise install pinned tools (e.g. bun on hosts without it).
if has mise && [[ -f "$HOME/.config/mise/config.toml" ]]; then
  log "mise install (pinned tools)"
  mise install 2>&1 | tail -3 || warn "mise install had problems; rerun later"
fi

cat <<'EOF'

[bootstrap] Done.

Next:
  exec zsh -l
  # First p10k run will print 'p10k configure' hint — your ~/.p10k.zsh is
  # already linked, so just answer 'y' if asked, or hit Enter to keep it.

If the secrets clone failed (private repo permissions / no agent):
  mkdir -p ~/.config/dotfiles-secrets
  git clone git@github.com:adarshdotexe/dotfiles-secrets.git ~/.config/dotfiles-secrets
EOF
