#!/usr/bin/env bash
# Portable dev environment bootstrap.
# Works with or without sudo. Idempotent.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/advarshney/dotfiles/main/bootstrap.sh | bash
#
# Env overrides:
#   DOTFILES_REPO=https://github.com/advarshney/dotfiles.git
#   DOTFILES_DIR=$HOME/repos/dotfiles

set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/advarshney/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/repos/dotfiles}"
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

# tmux >= 3.2 is needed for sesh's popup picker
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
  local tmp
  tmp=$(mktemp -d)
  curl -fLs "https://micro.mamba.pm/api/micromamba/${arch}/latest" \
    | tar -xj -C "$tmp" bin/micromamba
  mv -f "$tmp/bin/micromamba" "$LOCAL_BIN/micromamba"
  rm -rf "$tmp"
}

mamba_install() {
  install_micromamba
  log "micromamba install: $*"
  export MAMBA_ROOT_PREFIX="$MAMBA_ROOT"
  "$LOCAL_BIN/micromamba" install -y -p "$MAMBA_ENV" -c conda-forge "$@"
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

if ! has starship; then
  log "Installing starship"
  curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$LOCAL_BIN" >/dev/null
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
    x86_64)  SA=x86_64 ;;
    aarch64|arm64) SA=arm64 ;;
    *) SA=$(uname -m) ;;
  esac
  VER=$(curl -fsSL https://api.github.com/repos/joshmedeski/sesh/releases/latest \
        | awk -F'"' '/"tag_name":/{print $4; exit}')
  curl -fsSL "https://github.com/joshmedeski/sesh/releases/download/${VER}/sesh_Linux_${SA}.tar.gz" \
    | tar -xz -C "$LOCAL_BIN" sesh
  chmod +x "$LOCAL_BIN/sesh"
fi

# Stage 4: link configs (creates $HOME/.zshrc symlink before oh-my-zsh runs).
log "Linking configs"
"$DOTFILES_DIR/link.sh"

# Stage 5: oh-my-zsh + custom plugins.
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log "Installing oh-my-zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended
fi
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
clone_omz_plugin() {
  local repo="$1" dest="$2"
  [[ -d "$dest" ]] || git clone --depth 1 "https://github.com/$repo.git" "$dest"
}
clone_omz_plugin zsh-users/zsh-autosuggestions     "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_omz_plugin zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_omz_plugin Aloxaf/fzf-tab                    "$ZSH_CUSTOM/plugins/fzf-tab"

# Stage 6: mise install pinned runtimes (skip if no network or slow).
if has mise && [[ -f "$HOME/.config/mise/config.toml" ]]; then
  log "Installing mise-managed runtimes (this can take a few minutes)"
  mise install 2>&1 | tail -5 || warn "mise install had problems; rerun 'mise install' later"
fi

cat <<'EOF'

[bootstrap] Done.

Next steps:
  1. Ensure ~/.local/bin is in PATH for non-login shells:
       export PATH="$HOME/.local/bin:$PATH"
     (your dotfiles .zshenv already does this)
  2. Start a fresh shell:
       exec zsh -l
  3. From inside tmux, hit  Prefix + K  to open the sesh session picker.

If you installed userland micromamba tools, $HOME/.local/micromamba/envs/dotfiles/bin
is also on your PATH automatically via .zshenv.
EOF
