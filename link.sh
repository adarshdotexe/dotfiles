#!/usr/bin/env bash
# Symlinks the contents of each "package" subdir into $HOME, mirroring layout.
# Backs up any pre-existing real files to .backup.<timestamp>.

set -euo pipefail

if [[ -z "${HOME:-}" ]]; then
  echo "link.sh: \$HOME is empty; refusing to link" >&2
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
PKGS=(zsh tmux sesh git mise)

ts=$(date +%s)
backup_one() {
  local target="$1"
  if [[ -L "$target" ]]; then
    rm -f "$target"
  elif [[ -e "$target" ]]; then
    mv "$target" "$target.backup.$ts"
    printf '[link] backed up existing %s -> %s.backup.%s\n' "$target" "$target" "$ts"
  fi
}

for pkg in "${PKGS[@]}"; do
  pkgdir="$DIR/$pkg"
  [[ -d "$pkgdir" ]] || continue
  while IFS= read -r -d '' src; do
    rel="${src#$pkgdir/}"
    # Skip the placeholder used to keep empty dirs in git.
    [[ "$(basename "$src")" == ".gitkeep" ]] && continue
    dest="$HOME/$rel"
    mkdir -p "$(dirname "$dest")"
    backup_one "$dest"
    ln -s "$src" "$dest"
  done < <(find "$pkgdir" \( -type f -o -type l \) -print0)
done

printf '[link] done.\n'
