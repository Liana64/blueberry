# History
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt SHARE_HISTORY

# Completion
autoload -Uz compinit && compinit

# Plugins (Fedora paths)
[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Edit command in nvim with ctrl-e
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^E" edit-command-line
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# Tool integrations
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
command -v atuin &>/dev/null && eval "$(atuin init zsh)" && bindkey '^r' atuin-search && bindkey '^[[A' atuin-up-search && bindkey '^[OA' atuin-up-search
command -v starship &>/dev/null && eval "$(starship init zsh)"

# --- Aliases ---

# Editors
alias vi="nvim"
alias vim="nvim"
alias n="nvim"

# ls (eza)
alias l="eza -la --git --group-directories-first"
alias ll="eza -la --git --group-directories-first"
alias ls="eza"
alias l1="eza -1"

# grep (ripgrep)
alias ug="rg"
alias grep="rg"
alias egrep="rg -E"
alias fgrep="rg -F"
alias xzgrep="rg -z"
alias xzegrep="rg -zE"
alias xzfgrep="rg -zF"

# Personal
alias k="kubectl"
alias xclip="wl-copy"
alias clip="wl-copy"
alias myip="curl -s ifconfig.me"
alias weather="curl -s wttr.in/Chicago"

# Kubernetes
alias sec-tools="kubectl exec -it deploy/sec-tools -- zsh"
alias blog="kubectl rollout restart deployment blog -n default"

# Rust replacements
alias http="xh"
alias tree="eza --tree"
alias cat="bat"
alias catp="bat -p"
alias df="duf"
alias diff="delta"
alias du="dust"
alias find="fd --"
alias top="btop"
alias htop="btop"
alias neofetch="fastfetch"
alias ps="procs"

# Networking
alias fastping="ping -c 100 -i 0.2"
alias ports="ss -tunapl"
alias listening="ss -tlnp"
alias netstat="ss"

# Utility
alias bc="bc -l"
alias h="history"
alias j="jobs -l"
alias uu="uuidgen -x | tr '[:lower:]' '[:upper:]'"
alias gpg-encrypt="gpg -c --no-symkey-cache --cipher-algo=AES256"
alias gpg-decrypt="gpg -d"

# Git
alias g="git"
alias gl="git pull"
alias gd="git diff"

# Show all aliases
alias aliases="alias"

# Fortune (if available)
command -v fortune &>/dev/null && fortune
