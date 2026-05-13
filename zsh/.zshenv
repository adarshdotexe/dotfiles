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

# bun global bins (codex, etc.) — bootstrap Stage 10 installs here.
[[ -d "$HOME/.bun/bin" ]] && path=("$HOME/.bun/bin" $path)

export PATH

# Defaults useful even for non-interactive ssh-as-command invocations.
export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--FRX}"
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

export MISE_DATA_DIR="$HOME/.local/share/mise"

# Anthropic / Claude Code config (non-secret URL/model). Set here in .zshenv so
# non-interactive zsh (e.g. `zsh -c 'claude ...'`) also picks them up.
# Use ${VAR:-default} so existing env values (e.g. from sshd pam_env) win.
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://inference-api.nvidia.com/}"
export ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-aws/anthropic/bedrock-claude-opus-4-6[1m]}"
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
export CLAUDE_CODE_NO_FLICKER=1

# Secrets — sourced eagerly so non-interactive zsh (e.g. `zsh -c '...'`) also
# has the keys.
[[ -r "$HOME/.config/dotfiles-secrets/secrets.zsh" ]] && \
  source "$HOME/.config/dotfiles-secrets/secrets.zsh"

# OpenAI-compatible config — same key as Anthropic on the NVIDIA inference
# gateway. Set AFTER secrets so $ANTHROPIC_API_KEY is populated.
export OPENAI_API_KEY="${OPENAI_API_KEY:-$ANTHROPIC_API_KEY}"
export OPENAI_BASE_URL="${OPENAI_BASE_URL:-https://inference-api.nvidia.com/v1/}"
export OPENAI_MODEL="${OPENAI_MODEL:-openai/openai/gpt-5.5}"
