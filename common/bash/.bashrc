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

  local arg name dest i force=false end_of_opts=false status=0
  for arg in "$@"; do
    # Skip rm options (-r, -f, -rf, ...): moving to trash is always recursive
    if [ "$end_of_opts" = false ]; then
      case "$arg" in
        --) end_of_opts=true; continue ;;
        -*f*) force=true; continue ;;
        -?*) continue ;;
      esac
    fi

    if [ ! -e "$arg" ] && [ ! -L "$arg" ]; then
      [ "$force" = true ] || { echo "rm: $arg: No such file or directory" >&2; status=1; }
      continue
    fi

    # Never overwrite an earlier file with the same name in the trash
    name=$(basename -- "$arg")
    dest="$trash_dir/$name"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      dest="$trash_dir/$name.$(date +%Y%m%d_%H%M%S)"
      i=1
      while [ -e "$dest" ] || [ -L "$dest" ]; do
        dest="$trash_dir/$name.$(date +%Y%m%d_%H%M%S)_$i"
        i=$((i + 1))
      done
    fi

    if command mv -- "$arg" "$dest"; then
      echo "$arg deleted."
    else
      status=1
    fi
  done
  return $status
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

    # setGitPrompt re-sources the theme files on every prompt. Once
    # `bootstrap.sh --uninstall` removes ~/.bash-git-prompt, the shell that ran
    # it would print "No such file or directory" before every prompt. Wrap it so
    # the running shell falls back to a plain prompt instead.
    __dotx_git_prompt() {
        if [ -f "$HOME/.bash-git-prompt/gitprompt.sh" ]; then
            setGitPrompt
        else
            PROMPT_COMMAND=""
            PS1="${OLD_GITPROMPT:-\u@\h:\w\$ }"
        fi
    }
    PROMPT_COMMAND="${PROMPT_COMMAND//setGitPrompt/__dotx_git_prompt}"
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
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$PATH:$HOME/.local/bin"
fi

# ============================================================================
# nvm
# ============================================================================

export NVM_DIR="$HOME/.nvm"
# This loads nvm
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# This loads nvm bash_completion
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ============================================================================
# Rust
# ============================================================================

# Cargo installs executables to ~/.cargo/bin
if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]] && [ -d "$HOME/.cargo/bin" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi

# ============================================================================
# Claude Code
# ============================================================================

# Account-switching aliases using CLAUDE_CONFIG_DIR
# Usage: run alias, then /login inside the session to authenticate
alias claude-work='CLAUDE_CONFIG_DIR=~/.claude-work claude'
