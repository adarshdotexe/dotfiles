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

# ------------------------------------------------------------------ wezterm mux
WEZTERM_VERSION="${WEZTERM_VERSION:-20240203-110809-5046fc22}"

detect_wezterm_dist() {
  if [[ -n "${WEZTERM_DIST:-}" ]]; then
    echo "$WEZTERM_DIST"
    return
  fi

  local id="" version_id="" major=0
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-}"
    version_id="${VERSION_ID:-}"
    major="${version_id%%.*}"
    [[ "$major" =~ ^[0-9]+$ ]] || major=0
  fi

  case "$id" in
    ubuntu)
      if (( major >= 22 )); then echo Ubuntu22.04; else echo Ubuntu20.04; fi
      ;;
    debian)
      if (( major >= 12 )); then echo Debian12; elif (( major >= 11 )); then echo Debian11; else echo Debian10; fi
      ;;
    *)
      echo Debian10
      ;;
  esac
}

install_wezterm_remote() {
  local wezterm_dist; wezterm_dist=$(detect_wezterm_dist)
  local prefix="$HOME/.local/opt/wezterm-$WEZTERM_VERSION-$wezterm_dist"
  if [[ -x "$LOCAL_BIN/wezterm" && -x "$LOCAL_BIN/wezterm-mux-server" ]] \
     && "$LOCAL_BIN/wezterm" --version 2>/dev/null | grep -q "$WEZTERM_VERSION"; then
    log "WezTerm already installed: $("$LOCAL_BIN/wezterm" --version)"
    return 0
  fi

  local asset="wezterm-$WEZTERM_VERSION.$wezterm_dist.tar.xz"
  local url="https://github.com/wezterm/wezterm/releases/download/$WEZTERM_VERSION/$asset"
  local tmp; tmp=$(mktemp -d)
  log "Installing WezTerm mux binaries: $asset"

  if ! curl -fL "$url" -o "$tmp/$asset"; then
    rm -rf "$tmp"
    err "Could not download $url"
    return 1
  fi

  rm -rf "$prefix"
  mkdir -p "$prefix"
  tar -xJf "$tmp/$asset" -C "$prefix"
  rm -rf "$tmp"

  local wezterm_bin mux_bin
  wezterm_bin=$(find "$prefix" -type f -path '*/bin/wezterm' -perm /111 | head -n 1 || true)
  mux_bin=$(find "$prefix" -type f -path '*/bin/wezterm-mux-server' -perm /111 | head -n 1 || true)
  if [[ -z "$wezterm_bin" || -z "$mux_bin" ]]; then
    err "WezTerm archive did not contain expected binaries"
    return 1
  fi

  ln -sfn "$wezterm_bin" "$LOCAL_BIN/wezterm"
  ln -sfn "$mux_bin" "$LOCAL_BIN/wezterm-mux-server"
  log "WezTerm: $("$LOCAL_BIN/wezterm" --version)"
}

# tt helpers are kept as live symlinks to the source files in the repo so a
# `git pull` on a remote is enough to update them.
install_tt_helper() {
  local name="$1" src_rel="$2"
  local src="$DOTFILES_DIR/$src_rel"
  local dst="$LOCAL_BIN/$name"
  if [[ ! -r "$src" ]]; then
    warn "tt helper source missing at $src; skipping $name"
    return 0
  fi
  chmod +x "$src" 2>/dev/null || true
  if [[ -L "$dst" || -e "$dst" ]]; then rm -f "$dst"; fi
  ln -sf "$src" "$dst"
  log "Linked $name -> $src"
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

# ------------------------------------------------------------------ bash env
# Appends a guarded init block to ~/.bashrc and ~/.profile (idempotent):
#   - adds ~/.local/bin, mise shims, and the userland micromamba env to PATH
#   - sources secrets.zsh (POSIX-compatible content; works in bash too)
wire_bash_secrets() {
  local marker='# dotfiles: bash environment v2 (PATH + env + secrets)'
  local rc
  for rc in "$HOME/.bashrc" "$HOME/.profile"; do
    [[ -e "$rc" ]] || continue
    if ! grep -qF "$marker" "$rc" 2>/dev/null; then
      log "Adding bash env block (v2) to $rc"
      cat >> "$rc" <<'SNIPPET'

# dotfiles: bash environment v2 (PATH + env + secrets)
for _d in "$HOME/.local/bin" "$HOME/.local/share/mise/shims" "$HOME/.local/micromamba/envs/dotfiles/bin"; do
  case ":$PATH:" in
    *":$_d":*) ;;
    *) [ -d "$_d" ] && PATH="$_d:$PATH" ;;
  esac
done
unset _d
export PATH
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://inference-api.nvidia.com/}"
# ANTHROPIC_MODEL is set in ~/.claude/settings.json (model: opus-4-7[1m]) --
# keeping it here too would shadow the settings file.
export ANTHROPIC_DEFAULT_OPUS_MODEL="${ANTHROPIC_DEFAULT_OPUS_MODEL:-aws/anthropic/bedrock-claude-opus-4-7}"
export ANTHROPIC_DEFAULT_SONNET_MODEL="${ANTHROPIC_DEFAULT_SONNET_MODEL:-aws/anthropic/bedrock-claude-sonnet-4-6-v1}"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-aws/anthropic/bedrock-claude-haiku-4-5-v1}"
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
export CLAUDE_CODE_NO_FLICKER=1
[ -r "$HOME/.config/dotfiles-secrets/secrets.zsh" ] && . "$HOME/.config/dotfiles-secrets/secrets.zsh"
SNIPPET
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
WANT_SYS=(git curl zsh)
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
has zsh        || MAMBA_NEED+=(zsh)
has bat        || MAMBA_NEED+=(bat)
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
# Stage 3a: WezTerm mux + tt helper.
install_wezterm_remote || warn "WezTerm mux install failed; tt remote persistence won't work until fixed"
install_tt_helper tt-wezterm-session windows/tt-wezterm-session.sh

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

# Stage 5: link committed configs into $HOME (.zshrc, .zshenv, .aliases,
# .p10k.zsh, .gitconfig, mise under ~/.config/).
log "Linking configs"
bash "$DOTFILES_DIR/link.sh"

# Stage 6: secrets repo (after link, so .zshrc is ready to source it).
ensure_secrets_repo

# Stage 6a: symlink SSH config from the private secrets repo if present.
if [[ -r "$SECRETS_DIR/ssh-config" ]]; then
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  if [[ -L "$HOME/.ssh/config" ]]; then
    rm -f "$HOME/.ssh/config"
  elif [[ -e "$HOME/.ssh/config" ]]; then
    mv "$HOME/.ssh/config" "$HOME/.ssh/config.bootstrap-backup.$(date +%s)"
  fi
  ln -sfn "$SECRETS_DIR/ssh-config" "$HOME/.ssh/config"
  log "Linked $HOME/.ssh/config -> $SECRETS_DIR/ssh-config"
fi

# Stage 7a: also make bash see ANTHROPIC_API_KEY etc.
wire_bash_secrets

# Stage 7: wire the dotfiles Claude rule into global ~/.claude/CLAUDE.md.
wire_claude_rule

# Stage 8: mise install pinned tools (e.g. bun on hosts without it).
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
