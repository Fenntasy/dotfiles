export VISUAL=nvim
export EDITOR="$VISUAL"
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# ZSH configuration
setopt HIST_IGNORE_SPACE
setopt EXTENDED_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
source ${HOME}/.zsh/zcompletion
source ${HOME}/.zsh/zaliases
source ${HOME}/.zprofile

# ZSH Bindings
bindkey -e
bindkey '^[[1;9D' backward-word # Alt-Left
bindkey '^[[1;9C' forward-word # Alt-Right
bindkey '^[[3~' delete-char # Delete
bindkey '^[[Z' reverse-menu-complete # Ctrl-r
bindkey '^[[A' up-line-or-search # Arrow up
bindkey '^[[B' down-line-or-search # Arrow down

PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
PATH="/usr/local/sbin:$PATH"
PATH="${HOME}/.local/bin:${PATH}"
PATH="./node_modules/.bin:${PATH}"
PATH="${HOME}/.bin:${PATH}"
PATH="/Library/TeX/texbin/:$PATH"

export PATH

export HOMEBREW_BUNDLE_FILE=${HOME}/.Brewfile
export HOMEBREW_BUNDLE_NO_LOCK=true

# Prompt
if [[ $TEACHER_MODE ]]; then
  setopt PROMPT_SUBST
  export PROMPT='%B%c%b%f %(?.%F{24}❯%f.%F{198}❯%f) '
else
  eval "$(starship init zsh)"
fi

# FZF
export FZF_DEFAULT_OPTS="--color=light"

# allow signed git commits
export GPG_TTY=$(tty)

DISABLE_AUTO_TITLE="true"

eval "$(mise activate zsh)"

# Source secrets (CDPATH, tokens, etc.)
[[ -f ${HOME}/.zshrc.secrets ]] && source ${HOME}/.zshrc.secrets
