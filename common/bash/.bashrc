# Common bash configuration
# Shared across all platforms

# ============================================================================
# Environment Variables
# ============================================================================

export EDITOR=vim
export VISUAL=vim

# Color settings
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad

# Locale settings
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ============================================================================
# Functions
# ============================================================================

# Safe delete - move to trash instead of rm
function _rm {
  # Use TRASH_DIR from platform-specific config, fallback to /tmp
  local trash_dir="${TRASH_DIR:-/tmp}"

  # Create trash directory if it doesn't exist
  [ ! -d "$trash_dir" ] && mkdir -p "$trash_dir"

  while [ $# -ge 1 ]; do
    mv -f "$1" "$trash_dir"
    echo "$1 deleted."
    shift
  done
}

# ============================================================================
# Aliases
# ============================================================================

# Common utilities
alias du='du -h'
alias find='find . -name'
alias grep='grep --color=auto'
alias h='history | grep'
alias mkdir='mkdir -pv'
alias ls='ls -G'
alias mv='mv -i'
alias path='echo -e ${PATH//:/\\n}'
alias rm='_rm'
alias rrm='/bin/rm -i'
alias less='less -R'

# ============================================================================
# Bash Git Prompt
# ============================================================================

if [ -f "$HOME/.bash-git-prompt/gitprompt.sh" ]; then
    GIT_PROMPT_THEME=WonderChang
    source "$HOME/.bash-git-prompt/gitprompt.sh"
fi

# ============================================================================
# History Settings
# ============================================================================

export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# ============================================================================
# PATH Configuration
# ============================================================================

# User's private bin
if [ -d "$HOME/bin" ]; then
  export PATH="$HOME/bin:$PATH"

  # Source personal PATH if exists
  if [ -f "$HOME/bin/PATH" ]; then
    source "$HOME/bin/PATH"
  fi
fi

# ============================================================================
# Load Local Customizations
# ============================================================================

if [ -f "$HOME/.bashrc.local" ]; then
    source "$HOME/.bashrc.local"
fi

# ============================================================================
# pyenv
# ============================================================================

export PYENV_ROOT="$HOME/.pyenv"
# Only load pyenv if it's installed
if [ -d "$PYENV_ROOT" ]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init - bash)"
fi

# ============================================================================
# pipx & uv
# ============================================================================

# pipx and uv both install executables to ~/.local/bin
export PATH="$PATH:$HOME/.local/bin"

# ============================================================================
# nvm
# ============================================================================

export NVM_DIR="$HOME/.nvm"
# This loads nvm
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# This loads nvm bash_completion
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
