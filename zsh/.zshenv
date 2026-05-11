# .zshenv — sourced for ALL zsh invocations (including non-interactive).
# Keep it minimal: only env + PATH.

typeset -U path PATH

# Userland binaries from bootstrap (mise, zoxide, sesh, starship, fzf, micromamba).
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)

# micromamba dotfiles env (mosh, possibly tmux/zsh on no-sudo hosts).
[[ -d "$HOME/.local/micromamba/envs/dotfiles/bin" ]] \
  && path=("$HOME/.local/micromamba/envs/dotfiles/bin" $path)

# mise shims fallback (when `mise activate` hasn't run yet, e.g. cron/ssh-as-non-tty).
[[ -d "$HOME/.local/share/mise/shims" ]] && path=("$HOME/.local/share/mise/shims" $path)

export PATH

# Default tools that ssh-without-tty assumes.
export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--FRX}"

# Locale (containers often miss this).
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Tell mise where to keep its data.
export MISE_DATA_DIR="$HOME/.local/share/mise"
