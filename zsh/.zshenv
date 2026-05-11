# .zshenv — sourced for ALL zsh invocations (login, interactive, scripts).
# Keep it minimal: env + PATH only.

typeset -U path PATH

# Userland binaries from bootstrap (mise, zoxide, sesh, starship, fzf, micromamba).
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)

# Micromamba 'dotfiles' env (mosh on no-sudo hosts, possibly tmux/zsh too).
[[ -d "$HOME/.local/micromamba/envs/dotfiles/bin" ]] \
  && path=("$HOME/.local/micromamba/envs/dotfiles/bin" $path)

# mise shims fallback for non-interactive subshells.
[[ -d "$HOME/.local/share/mise/shims" ]] && path=("$HOME/.local/share/mise/shims" $path)

export PATH

# Defaults useful even for non-interactive ssh-as-command invocations.
export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--FRX}"
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

export MISE_DATA_DIR="$HOME/.local/share/mise"
