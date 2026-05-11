# .zshrc — interactive shell config.

# ---------------------------------------------------------------- oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""          # starship handles the prompt
DISABLE_AUTO_UPDATE="true"
ZSH_DISABLE_COMPFIX="true"
plugins=(
  git
  fzf-tab
  zsh-autosuggestions
  zsh-syntax-highlighting    # keep this last
)
[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# ---------------------------------------------------------------- history
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS EXTENDED_HISTORY

# ---------------------------------------------------------------- options
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP
setopt PROMPT_SUBST

# ---------------------------------------------------------------- key bindings
bindkey -e
bindkey '^[[A' history-substring-search-up   2>/dev/null
bindkey '^[[B' history-substring-search-down 2>/dev/null

# ---------------------------------------------------------------- modular fragments
for f in "$HOME/.zsh/"*.zsh(N); do source "$f"; done

# ---------------------------------------------------------------- tool inits (each guarded)
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh --cmd cd)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# fzf keybindings if installed via git checkout in ~/.fzf
[[ -r "$HOME/.fzf/shell/key-bindings.zsh" ]] && source "$HOME/.fzf/shell/key-bindings.zsh"
[[ -r "$HOME/.fzf/shell/completion.zsh"   ]] && source "$HOME/.fzf/shell/completion.zsh"

# sesh quick-open
if command -v sesh >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then
  function sesh-connect() {
    local session
    session=$(sesh list -i 2>/dev/null | fzf-tmux -p 60%,55% \
      --no-sort --ansi --border-label ' sesh ' --prompt '> ' --header '^a all  ^t tmux  ^g configs  ^x zoxide  ^d kill') || return
    [[ -n "$session" ]] && sesh connect "$session"
  }
  alias s='sesh-connect'
fi

# ---------------------------------------------------------------- conveniences
alias ll='ls -lah'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias gst='git status -sb'
alias gco='git checkout'
alias gsw='git switch'
alias gl='git log --oneline --decorate --graph -20'
alias claude-here='claude --add-dir "$(pwd)"'
