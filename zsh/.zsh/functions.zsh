# Custom functions.

# mkcd: make a dir and cd into it.
mkcd() {
  [[ -z "$1" ]] && { echo "usage: mkcd <dir>"; return 1; }
  mkdir -p "$1" && cd "$1"
}

# upd: pull dotfiles repo and re-link.
upd() {
  local dir="${DOTFILES_DIR:-$HOME/repos/dotfiles}"
  if [[ ! -d "$dir/.git" ]]; then
    echo "dotfiles not at $dir"; return 1
  fi
  ( cd "$dir" && git pull --ff-only && ./link.sh )
  echo "now: exec zsh -l"
}

# extract: dwim archive extraction.
extract() {
  [[ -f "$1" ]] || { echo "extract: not a file: $1"; return 1; }
  case "$1" in
    *.tar.bz2|*.tbz2) tar xjf "$1" ;;
    *.tar.gz|*.tgz)   tar xzf "$1" ;;
    *.tar.xz)         tar xJf "$1" ;;
    *.tar)            tar xf  "$1" ;;
    *.zip)            unzip   "$1" ;;
    *.bz2)            bunzip2 "$1" ;;
    *.gz)             gunzip  "$1" ;;
    *.xz)             unxz    "$1" ;;
    *.7z)             7z x    "$1" ;;
    *) echo "extract: unsupported: $1"; return 1 ;;
  esac
}

# tmux-claude: start or attach a tmux session named after the basename of cwd
# and run claude in window 0 if not already running.
tmux-claude() {
  local name="${1:-$(basename "$PWD")}"
  if tmux has-session -t "$name" 2>/dev/null; then
    tmux attach -t "$name"
  else
    tmux new-session -d -s "$name" -c "$PWD"
    tmux send-keys -t "$name" 'claude' C-m
    tmux attach -t "$name"
  fi
}
