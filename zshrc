export CDPATH=~:~/Workspace:~/Workspace/fewlinesco
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
PATH="${HOME}/.asdf/shims:${PATH}"
PATH="./node_modules/.bin:${PATH}"
PATH="${HOME}/Library/Android//sdk/platform-tools:${PATH}"
PATH="${HOME}/.bin:${PATH}"
PATH="${HOME}/.fewlines-dotfiles:${PATH}"

export PATH

export HOMEBREW_BUNDLE_FILE=${HOME}/.Brewfile
export HOMEBREW_BUNDLE_NO_LOCK=true

function current_directory_prompt() {
  echo ${PWD/#$HOME/\~} | sed -E 's/([^/])[^/]*\//\1\//g'
}

function _currentKubernetesContextName() {
  local context=$(kubectl config current-context 2> /dev/null);

  if [ -z "${context}" -o "${context}" = "docker-desktop" ]; then
    echo ""
  else
    echo "%{%F{1}%} ${context}%{%f%} "
  fi
}

setopt prompt_subst
export PROMPT='%F{blue}$(current_directory_prompt)%f $(_currentKubernetesContextName)%F{green}❯%f '

# ASDF
. $HOME/.asdf/asdf.sh

# Kubernetes
export TILLER_NAMESPACE=tiller
export HELM_TLS_ENABLE=true

# Erlang
export KERL_CONFIGURE_OPTIONS="--disable-debug --without-javac --with-wx"

# Go
export GOPATH="${HOME}/Workspace/go"
export PATH=$PATH:$GOPATH/bin

# Android
export ANDROID_HOME=/Users/fenn/Library/Android/sdk
export ANDROID_SDK_ROOT=/Users/fenn/Library/Android/sdk

# allow signed git commits
export GPG_TTY=$(tty)

# FZF
export FZF_DEFAULT_OPTS="--color=light"

DISABLE_AUTO_TITLE="true"

current_tt
source /usr/local/Caskroom/yandex-cloud-cli/latest/yandex-cloud-cli/completion.zsh.inc
