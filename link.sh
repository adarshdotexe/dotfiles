#!/usr/bin/env bash
# Symlinks the contents of each "package" subdir into $HOME, mirroring layout.
# Backs up any pre-existing real files to .backup.<timestamp>.
#
# Replaces GNU stow so we have one less dependency on locked-down hosts.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PKGS=(zsh tmux sesh git mise starship)

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
    dest="$HOME/$rel"
    mkdir -p "$(dirname "$dest")"
    backup_one "$dest"
    ln -s "$src" "$dest"
  done < <(find "$pkgdir" \( -type f -o -type l \) -print0)
done

printf '[link] done.\n'
