# Adarsh's portable .zshrc — https://github.com/advarshney/dotfiles
# Host-specific paths and env are guarded with [[ -d ... ]] so the same file
# works on BAN, SC, H100, GB100, WSL, and anywhere else.
# Secrets live in a separate PRIVATE repo (advarshney/dotfiles-secrets),
# sourced at the bottom.

# -----------------------------------------------------------------------------
# 1. Powerlevel10k instant prompt (must stay near the top)
# -----------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -----------------------------------------------------------------------------
# 2. Ultra-fast completion init (skip compaudit, reuse cached dump)
# -----------------------------------------------------------------------------
autoload -Uz compinit
if [[ -f "${ZDOTDIR:-$HOME}/.zcompdump" ]]; then
  compinit -C
else
  compinit -i
fi
skip_global_compinit=1

# Deno (and other tools) drop completion files here.
if [[ -d "$HOME/.zsh/completions" ]]; then
  [[ ":$FPATH:" != *":$HOME/.zsh/completions:"* ]] && \
    export FPATH="$HOME/.zsh/completions:$FPATH"
fi

# -----------------------------------------------------------------------------
# 3. PATH — host-specific dirs added only if they exist
# -----------------------------------------------------------------------------
typeset -U path
_add_path() { [[ -d "$1" ]] && path=("$1" $path); }

# NVIDIA /home/utils tools (BAN, SC, similar Rocky 8 xterms)
for d in \
  /home/utils/git-2.52.0/bin \
  /home/utils/gcc-13.3.0/bin \
  /home/utils/make-4.4.1/bin \
  /home/utils/flex-2.6.4/bin \
  /home/utils/bison-3.8.2/bin \
  /home/utils/gperf-3.1/bin \
  /home/utils/Python-3.12.5/bin \
  /home/utils/Python-3.8.0/bin \
  /home/utils/uv-0.7.10/bin \
  /home/utils/zsh-5.9/bin \
  /home/utils/vim-9.0.0630/bin \
  /home/utils/tcsh-6.19.00/bin \
  /home/utils/gdb-9.2/bin \
  /home/utils/tmux-3.5a/bin \
  /home/utils/screen-4.6.2/bin \
  /home/utils/perl-5.26/5.26.2-139/bin \
  /home/utils/cmake-3.29.2-ssl/bin \
  /home/utils/yarn-v1.10.1/bin \
  /home/utils/llvm-17.0.6/bin \
  /home/utils/sqlite-3.38.5/bin \
  /home/utils/fzf-0.54.3/bin \
  /home/utils/neovim-0.10.1/bin \
  /home/utils/openssl-1.1.1w/bin \
  /home/nv/utils/p4mapper/latest/bin \
  /home/nv/utils/crucible/1.0/bin \
  /home/tools/vault-agent/v2.1.0 \
  /home/scratch.advarshney_gpu/.starship \
  /home/scratch.advarshney_gpu/google-cloud-sdk/bin \
  /home/scratch.advarshney_gpu/homebrew/bin \
  /home/scratch.powerestimations_powerestimations/uv \
; do _add_path "$d"; done

# Userland (everywhere — bootstrap installs into here)
_add_path "$HOME/.local/micromamba/envs/dotfiles/bin"
_add_path "$HOME/.local/bin"
_add_path "$HOME/.bun/bin"
_add_path "$HOME/.deno/bin"

unfunction _add_path

# -----------------------------------------------------------------------------
# 4. Environment vars (non-secret only)
# -----------------------------------------------------------------------------
[[ -x /bin/gcc ]] && export CC=/bin/gcc
[[ -x /bin/g++ ]] && export CXX=/bin/g++

if [[ -d "/home/scratch.advarshney_gpu" ]]; then
  export SCRATCH_DIR="/home/scratch.advarshney_gpu"
  [[ -d "$SCRATCH_DIR/.bun" ]] && export BUN_INSTALL="$SCRATCH_DIR/.bun" && path=("$BUN_INSTALL/bin" $path)
fi

[[ -r "$HOME/.deno/env" ]] && . "$HOME/.deno/env"

# NVIDIA infra (not secret — these are well-known internal hostnames)
export P4PORT="${P4PORT:-p4proxy-bangalore:2001}"
export VAULT_ADDR="${VAULT_ADDR:-https://prod.vault.nvidia.com}"
export VAULT_NAMESPACE="${VAULT_NAMESPACE:-hw-infra-sec}"
export GLAB_HOST="${GLAB_HOST:-gitlab-master.nvidia.com}"

# Anthropic / Claude Code config (non-secret URL/model bits; API key in secrets repo)
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://inference-api.nvidia.com/}"
export ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-aws/anthropic/bedrock-claude-opus-4-6[1m]}"
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
export CLAUDE_CODE_NO_FLICKER=1

# OpenAI-compatible config — same key as Anthropic on the NVIDIA inference gateway.
export OPENAI_API_KEY="${OPENAI_API_KEY:-$ANTHROPIC_API_KEY}"
export OPENAI_BASE_URL="${OPENAI_BASE_URL:-https://inference-api.nvidia.com/v1/}"
export OPENAI_MODEL="${OPENAI_MODEL:-openai/openai/gpt-5.5}"

# -----------------------------------------------------------------------------
# 5. Aliases — sourced from ~/.aliases (also a symlinked dotfile)
# -----------------------------------------------------------------------------
[[ -r "$HOME/.aliases" ]] && source "$HOME/.aliases"

# Functions split out into ~/.zsh/*.zsh (e.g. cchost.zsh).
for f in "$HOME/.zsh/"*.zsh(N); do source "$f"; done

# -----------------------------------------------------------------------------
# 6. Oh My Zsh + Powerlevel10k
# -----------------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

zstyle ":omz:update" mode auto
zstyle ":omz:update" frequency 7

# Weekly pull of custom OMZ plugins + p10k theme (silent, non-blocking)
_update_custom_plugins() {
  local marker="$ZSH/custom/.last_plugin_update"
  local now=$(date +%s) last=0
  [[ -f "$marker" ]] && last=$(cat "$marker")
  if (( (now - last) / 86400 >= 7 )); then
    echo "$now" > "$marker"
    for d in "$ZSH"/custom/plugins/*/; do
      [[ -d "$d/.git" ]] && (cd "$d" && git pull -q &) 2>/dev/null
    done
    [[ -d "$ZSH/custom/themes/powerlevel10k/.git" ]] && \
      (cd "$ZSH/custom/themes/powerlevel10k" && git pull -q &) 2>/dev/null
    wait
  fi
}
_update_custom_plugins

DISABLE_MAGIC_FUNCTIONS="true"
export ZOXIDE_CMD_OVERRIDE=cd

plugins=(
  git
  zoxide
  # syntax-highlighting, autosuggestions, history-substring-search loaded
  # deferred below for faster startup.
)

zstyle ':omz:plugins:nvm' lazy yes

# -----------------------------------------------------------------------------
# 7. Shell options
# -----------------------------------------------------------------------------
ENABLE_CORRECTION="false"
unsetopt CORRECT CORRECT_ALL

# -----------------------------------------------------------------------------
# 8. History
# -----------------------------------------------------------------------------
HISTSIZE=100
HISTFILE=~/.histfile
SAVEHIST=100
setopt INC_APPEND_HISTORY SHARE_HISTORY EXTENDED_HISTORY APPENDHISTORY
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS HIST_IGNORE_SPACE

# -----------------------------------------------------------------------------
# 9. Keybindings (substring-search rebinds these in the deferred block)
# -----------------------------------------------------------------------------
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# -----------------------------------------------------------------------------
# 10. Perforce + termgpt (VS Code / Cursor aware)
# -----------------------------------------------------------------------------
if [[ -n "$VSCODE_GIT_ASKPASS_NODE" ]]; then
  path=($(dirname "$VSCODE_GIT_ASKPASS_NODE")/bin/remote-cli $path)
  export P4DIFF='cursor -dw'
  export P4EDITOR='cursor --wait'
  export CURSOR_CLI_BLOCK_CURSOR_AGENT=true
else
  [[ -x /home/utils/tkdiff-4.3.4/tkdiff ]] && export P4DIFF='/home/utils/tkdiff-4.3.4/tkdiff'
  export P4EDITOR='vim'

  if [[ -f "$HOME/termgpt" ]] || command -v termgpt >/dev/null 2>&1; then
    termgpt-widget() {
      local termgpt_script="$HOME/termgpt"
      command -v termgpt >/dev/null 2>&1 && termgpt_script="termgpt"
      [[ -f "./termgpt" ]] && termgpt_script="./termgpt"
      local prompt_text=""
      if [[ "$BUFFER" == "termgpt> "* ]]; then
        prompt_text="${BUFFER#termgpt> }"
        [[ -z "$prompt_text" ]] && return 0
      elif [[ -n "$BUFFER" ]]; then
        prompt_text="$BUFFER"
      else
        BUFFER="termgpt> "
        CURSOR=${#BUFFER}
        zle reset-prompt
        return 0
      fi
      local cmd exit_code
      cmd=$(timeout 10s "$termgpt_script" -p "$prompt_text" 2>&1)
      exit_code=$?
      if [[ $exit_code -eq 0 && -n "$cmd" ]]; then
        BUFFER="$cmd"
        CURSOR=${#BUFFER}
      else
        zle -M "termgpt error: $cmd"
        return 1
      fi
      zle reset-prompt
    }
    zle -N termgpt-widget
    bindkey '^G' termgpt-widget
  fi
fi

# -----------------------------------------------------------------------------
# 11. tmux env refresh helper (`refresh` inside a tmux session)
# -----------------------------------------------------------------------------
_refresh_tmux_env() {
  tmux show-environment 2>/dev/null | while IFS= read -r var; do
    [[ -z "$var" ]] && continue
    if [[ "$var" == -* ]]; then
      unset "${var#-}"
    else
      export "$var"
    fi
  done
  export VSCODE_IPC_HOOK_CLI=$(command ls -tr /tmp/vscode-ipc-* 2>/dev/null | tail -n 1)
}
if [[ -n "$TMUX" ]]; then
  alias refresh='_refresh_tmux_env'
else
  alias refresh=''
fi

# -----------------------------------------------------------------------------
# 12. NVM lazy-load (skip the ~3s startup hit)
# -----------------------------------------------------------------------------
export NVM_DIR="$HOME/.nvm"
nvm() { unfunction nvm node npm npx 2>/dev/null; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; nvm "$@"; }
node() { unfunction nvm node npm npx 2>/dev/null; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; node "$@"; }
npm() { unfunction nvm node npm npx 2>/dev/null; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; npm "$@"; }
npx() { unfunction nvm node npm npx 2>/dev/null; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; npx "$@"; }

# -----------------------------------------------------------------------------
# 13. Source Oh My Zsh
# -----------------------------------------------------------------------------
[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# -----------------------------------------------------------------------------
# 14. Powerlevel10k user config
# -----------------------------------------------------------------------------
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# -----------------------------------------------------------------------------
# 15. Deferred plugin load (after first prompt = faster startup)
# -----------------------------------------------------------------------------
_load_deferred_plugins() {
  [[ -r $ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source $ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  [[ -r $ZSH/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source $ZSH/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  [[ -r $ZSH/plugins/history-substring-search/history-substring-search.zsh ]] && \
    source $ZSH/plugins/history-substring-search/history-substring-search.zsh
  if typeset -f history-substring-search-up >/dev/null; then
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
  fi
}
autoload -Uz add-zsh-hook
_load_deferred_once() {
  add-zsh-hook -d precmd _load_deferred_once
  _load_deferred_plugins
}
add-zsh-hook precmd _load_deferred_once

# -----------------------------------------------------------------------------
# 16. SSH DISPLAY pass-through
# -----------------------------------------------------------------------------
if [[ -n "$SSH_CONNECTION" ]]; then
  ssh_client_ip=$(echo $SSH_CONNECTION | awk '{print $1}')
  export DISPLAY="$ssh_client_ip:0.0"
fi

# -----------------------------------------------------------------------------
# 17. Tool activations (guarded; quiet if tool missing)
# -----------------------------------------------------------------------------
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh --cmd cd)"
command -v mise   >/dev/null 2>&1 && eval "$(mise activate zsh)"

# sesh completion — regenerate when binary is newer than the cached file.
if command -v sesh >/dev/null 2>&1; then
  _sesh_comp="$HOME/.zsh/completions/_sesh"
  if [[ ! -f "$_sesh_comp" || "$(command -v sesh)" -nt "$_sesh_comp" ]]; then
    mkdir -p "$HOME/.zsh/completions"
    sesh completion zsh > "$_sesh_comp" 2>/dev/null
  fi
  unset _sesh_comp
fi

# fzf shell integration (if installed via `~/.fzf/install`)
[[ -r "$HOME/.fzf/shell/key-bindings.zsh" ]] && source "$HOME/.fzf/shell/key-bindings.zsh"
[[ -r "$HOME/.fzf/shell/completion.zsh"   ]] && source "$HOME/.fzf/shell/completion.zsh"

# -----------------------------------------------------------------------------
# 18. Secrets — from the private repo cloned by bootstrap.sh
# -----------------------------------------------------------------------------
[[ -r "$HOME/.config/dotfiles-secrets/secrets.zsh" ]] && \
  source "$HOME/.config/dotfiles-secrets/secrets.zsh"

# -----------------------------------------------------------------------------
# 19. Host-local overrides (never in git)
# -----------------------------------------------------------------------------
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
