# Aliases that aren't worth functions.

# Safer defaults
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Quick tmux
alias tat='tmux new-session -A -s main'
alias tls='tmux ls'

# Git brevity
alias g='git'
alias gd='git diff'
alias gds='git diff --staged'
alias gp='git pull --ff-only'
alias gpu='git push'
alias gb='git branch'
alias gc='git commit'
alias gcm='git commit -m'
alias gcam='git commit -am'

# mosh shorthand (uses your ssh config aliases: BAN, SC, etc.)
mo() {
  mosh "$1" -- tmux new -A -s main
}

# Claude Code in current dir, no prompt confirmation friction
alias cc='claude'
