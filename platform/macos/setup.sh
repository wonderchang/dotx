#!/usr/bin/env bash
# platform/macos/setup.sh
# macOS-specific setup orchestrator

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities
source "$PROJECT_ROOT/utils/symlink.sh"
source "$PROJECT_ROOT/utils/shell.sh"
source "$PROJECT_ROOT/utils/detect.sh"
source "$PROJECT_ROOT/utils/sudo.sh"

# Homebrew 7 asks "Do you want to proceed? [y/n]" before every install by
# default (ask mode); disable it so the run never blocks on a prompt.
export HOMEBREW_NO_ASK=1

# Every `brew` command runs `sudo --reset-timestamp` on startup, which throws
# away the password cached by request_sudo and makes the later shell switch
# (`sudo dscl`) ask again. Formulae never need sudo, so tell brew not to touch
# sudo at all (documented variable, see `brew help`/env_config.rb).
export HOMEBREW_NO_SUDO=1

# Component list to install/uninstall
COMPONENTS=()

# ============================================================================
# Package Management Helpers
# ============================================================================

install_brew_package() {
  local package="$1"

  if brew list "$package" &>/dev/null; then
    echo "✓ $package already installed"
  else
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would install $package via Homebrew"
    else
      echo "Installing $package..."
      brew install "$package"
      echo "✓ $package installed"
    fi
  fi
}

uninstall_brew_package() {
  local package="$1"

  if brew list "$package" &>/dev/null; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would uninstall $package via Homebrew"
    else
      echo "Uninstalling $package..."
      brew uninstall "$package"
      echo "✓ $package uninstalled"
    fi
  else
    echo "✓ $package not installed"
  fi
}

# Casks that only copy files under $(brew --prefix) and run user-level
# scripts (like gcloud-cli) need no sudo, so they work with HOMEBREW_NO_SUDO.
install_brew_cask() {
  local cask="$1"

  if brew list --cask "$cask" &>/dev/null; then
    echo "✓ $cask already installed"
  else
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would install cask $cask via Homebrew"
    else
      echo "Installing $cask..."
      brew install --cask "$cask"
      echo "✓ $cask installed"
    fi
  fi
}

# --zap also removes what the cask's zap stanza lists (for gcloud-cli the
# whole $(brew --prefix)/share/google-cloud-sdk tree); a plain uninstall
# would leave it behind.
uninstall_brew_cask() {
  local cask="$1"

  if brew list --cask "$cask" &>/dev/null; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would uninstall cask $cask via Homebrew (--zap)"
    else
      echo "Uninstalling $cask..."
      brew uninstall --cask --zap "$cask"
      echo "✓ $cask uninstalled"
    fi
  else
    echo "✓ $cask not installed"
  fi
}

# The gcloud-cli cask runs gcloud on a Python virtualenv under ~/.config/gcloud
# built from the python@3.x formula the cask depends on. Its postflight only
# builds that virtualenv when none exists yet: one left over from a hand
# install (e.g. on python.org Python) is kept as is, so check what the
# virtualenv points at and rebuild it on Homebrew Python when it does not.
ensure_gcloud_virtenv() {
  local virtenv="$HOME/.config/gcloud/virtenv"
  local formula python home

  formula=$(brew info --json=v2 --cask gcloud-cli 2>/dev/null \
    | grep -o '"python@3[.0-9]*"' | head -1 | tr -d '"')
  python="$(brew --prefix)/opt/${formula:-python@3.14}/libexec/bin/python"

  home=$(sed -n 's/^home = //p' "$virtenv/pyvenv.cfg" 2>/dev/null || true)
  if [ -n "$home" ] && [ -f "$virtenv/enabled" ] && [[ "$home" == "$(brew --prefix)/"* ]]; then
    echo "✓ gcloud virtualenv already on Homebrew Python: $home"
    return 0
  fi

  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would rebuild ~/.config/gcloud/virtenv on $python"
    return 0
  fi

  if [ ! -x "$python" ]; then
    echo "  ✗ Homebrew Python not found: $python (is the gcloud-cli cask installed?)"
    return 1
  fi

  echo "Rebuilding gcloud virtualenv on $python..."
  echo "  (current: ${home:-none})"
  if [ -d "$virtenv" ]; then
    CLOUDSDK_PYTHON="$python" gcloud config virtualenv delete --quiet
  fi
  CLOUDSDK_PYTHON="$python" gcloud config virtualenv create --python-to-use "$python" --quiet
  CLOUDSDK_PYTHON="$python" gcloud config virtualenv enable --quiet
  echo "✓ gcloud virtualenv rebuilt"
}

# The gcloud-cli cask runs gcloud on a Python virtualenv it creates under
# ~/.config/gcloud (backed by Homebrew Python). Remove that virtualenv,
# but keep the rest of ~/.config/gcloud: credentials and configurations were
# created by `gcloud auth`/`gcloud config`, not by dotx.
remove_gcloud_virtenv() {
  local virtenv="$HOME/.config/gcloud/virtenv"

  if [ -d "$virtenv" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would remove gcloud virtualenv: ~/.config/gcloud/virtenv"
    else
      rm -rf "$virtenv"
      echo "  Removed gcloud virtualenv: ~/.config/gcloud/virtenv"
    fi
  fi
  if [ -d "$HOME/.config/gcloud" ]; then
    echo "  Note: ~/.config/gcloud (credentials, configurations) is kept"
  fi
}

# Check if a component should be processed
should_install_component() {
  local component="$1"

  # If no components specified, install all
  if [ ${#COMPONENTS[@]} -eq 0 ]; then
    return 0
  fi

  # Check if 'all' is in components
  for c in "${COMPONENTS[@]}"; do
    if [ "$c" = "all" ]; then
      return 0
    fi
  done

  # Check if specific component is in list
  for c in "${COMPONENTS[@]}"; do
    if [ "$c" = "$component" ]; then
      return 0
    fi
  done

  return 1
}

# Ask for the password up front only when a later step will actually need it,
# so a no-op re-run stays silent.
request_sudo_for_install() {
  local reasons=()
  load_brew_shellenv
  if ! command -v brew &>/dev/null; then
    reasons+=("Homebrew installer")
  fi
  if should_install_component "bash" && [ "$(get_current_shell)" != "$(homebrew_bash_path)" ]; then
    reasons+=("switching the login shell to bash")
  fi
  if [ ${#reasons[@]} -gt 0 ]; then
    request_sudo "$(IFS=,; echo "${reasons[*]}")"
  fi
}

request_sudo_for_uninstall() {
  if should_install_component "bash" && [ "$(get_current_shell)" != "/bin/zsh" ]; then
    request_sudo "restoring the login shell to zsh"
  fi
}

install_macos() {
  echo "========================================"
  echo "  macOS Setup"
  echo "========================================"
  echo ""

  # 0. Ask for the password once, if any later step needs it
  request_sudo_for_install

  # 1. Install Homebrew (prerequisite)
  bash "$SCRIPT_DIR/homebrew.sh"
  # homebrew.sh runs in a subshell, so load brew's PATH here as well
  load_brew_shellenv

  # 2. Install tools with their packages
  if should_install_component "vim"; then
    echo "=== Vim ==="
    # Note: vim comes with macOS, using system vim
    bash "$PROJECT_ROOT/common/vim/setup.sh" install
    echo ""
  fi

  if should_install_component "git"; then
    echo "=== Git ==="
    # Note: git comes with macOS Xcode Command Line Tools
    bash "$PROJECT_ROOT/common/git/setup.sh" install
    echo ""
  fi

  if should_install_component "tmux"; then
    echo "=== Tmux ==="
    install_brew_package "tmux"
    bash "$PROJECT_ROOT/common/tmux/setup.sh" install
    bash "$SCRIPT_DIR/iterm2.sh" install
  fi

  if should_install_component "bash"; then
    echo "=== Bash ==="

    # 1. Install modern bash via Homebrew (macOS ships with old bash 3.2)
    echo "Installing bash via Homebrew..."
    install_brew_package "bash"
    echo ""

    # 2. Switch default shell to Homebrew bash (macOS defaults to zsh)
    echo "=== Switching Default Shell to Bash ==="
    switch_to_bash
    echo ""

    # 3. Install bash configuration
    bash "$PROJECT_ROOT/common/bash/setup.sh" install

    # 4. Setup platform-specific bash configuration
    echo "=== macOS-Specific Bash Configuration ==="
    create_symlink "$SCRIPT_DIR/.bashrc.macos" "$HOME/.bashrc.local"
    echo "✓ macOS bash configuration linked"
    echo ""
  fi

  if should_install_component "nvm"; then
    echo "=== NVM ==="
    bash "$PROJECT_ROOT/common/nvm/setup.sh" install
    echo ""
  fi

  if should_install_component "pyenv"; then
    bash "$PROJECT_ROOT/common/pyenv/setup.sh" install
    echo ""
  fi

  if should_install_component "pipx"; then
    echo "=== pipx ==="
    # Package manager install: `pip install --user` is blocked by PEP 668
    # on Homebrew Python and Ubuntu 23.04+ / Debian 12.
    # ~/.local/bin is already on PATH via .bashrc, so no `pipx ensurepath`.
    install_brew_package "pipx"
    echo ""
  fi

  if should_install_component "uv"; then
    bash "$PROJECT_ROOT/common/uv/setup.sh" install
    echo ""
  fi

  if should_install_component "rust"; then
    bash "$PROJECT_ROOT/common/rust/setup.sh" install
    echo ""
  fi

  if should_install_component "gcloud"; then
    echo "=== Google Cloud CLI ==="
    # The cask pulls in python@3.14, creates ~/.config/gcloud/virtenv on it,
    # and links gcloud/gsutil/bq into $(brew --prefix)/bin (already on PATH).
    # Completion is wired up in .bashrc.macos.
    install_brew_cask "gcloud-cli"
    ensure_gcloud_virtenv
    echo ""
  fi

  echo "========================================"
  echo "  ✓ macOS Setup Complete!"
  echo "========================================"
  echo ""
}

uninstall_macos() {
  echo "========================================"
  echo "  macOS Uninstall"
  echo "========================================"
  echo ""

  # 0. Ask for the password once, if any later step needs it
  request_sudo_for_uninstall

  # 1. Uninstall tools with their packages
  if should_install_component "vim"; then
    echo "=== Vim ==="
    bash "$PROJECT_ROOT/common/vim/setup.sh" uninstall
    # Note: Not uninstalling system vim
    echo ""
  fi

  if should_install_component "git"; then
    echo "=== Git ==="
    bash "$PROJECT_ROOT/common/git/setup.sh" uninstall
    # Note: Not uninstalling git (Xcode Command Line Tools)
    echo ""
  fi

  if should_install_component "tmux"; then
    echo "=== Tmux ==="
    bash "$SCRIPT_DIR/iterm2.sh" uninstall
    bash "$PROJECT_ROOT/common/tmux/setup.sh" uninstall
    uninstall_brew_package "tmux"
    echo ""
  fi

  if should_install_component "nvm"; then
    echo "=== NVM ==="
    bash "$PROJECT_ROOT/common/nvm/setup.sh" uninstall
    echo ""
  fi

  if should_install_component "pyenv"; then
    bash "$PROJECT_ROOT/common/pyenv/setup.sh" uninstall
    echo ""
  fi

  if should_install_component "pipx"; then
    echo "=== pipx ==="
    uninstall_brew_package "pipx"
    echo ""
  fi

  if should_install_component "uv"; then
    bash "$PROJECT_ROOT/common/uv/setup.sh" uninstall
    echo ""
  fi

  if should_install_component "rust"; then
    bash "$PROJECT_ROOT/common/rust/setup.sh" uninstall
    echo ""
  fi

  if should_install_component "gcloud"; then
    echo "=== Google Cloud CLI ==="
    uninstall_brew_cask "gcloud-cli"
    remove_gcloud_virtenv
    echo ""
  fi

  # Last: removing Homebrew bash breaks later `bash .../setup.sh` calls,
  # since `bash` is already resolved to the Homebrew path in this shell
  if should_install_component "bash"; then
    echo "=== Bash ==="

    # 1. Restore shell to zsh (macOS default)
    echo "=== Restoring Default Shell to Zsh ==="
    restore_shell "/bin/zsh"
    echo ""

    # 2. Remove bash configurations
    bash "$PROJECT_ROOT/common/bash/setup.sh" uninstall

    # 3. Remove platform-specific bash configuration
    echo "=== macOS-Specific Bash Uninstall ==="
    remove_symlink "$HOME/.bashrc.local"
    echo ""

    # 4. Uninstall Homebrew bash
    echo "Uninstalling Homebrew bash..."
    uninstall_brew_package "bash"
    echo ""
  fi

  echo "========================================"
  echo "  ✓ macOS Uninstall Complete!"
  echo "========================================"
  echo ""
}

# Execute based on mode
MODE="${1:-install}"
shift || true

# Collect component arguments
COMPONENTS=("$@")

case "$MODE" in
  install)
    install_macos
    ;;
  uninstall)
    uninstall_macos
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
