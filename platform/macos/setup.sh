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

install_macos() {
  echo "========================================"
  echo "  macOS Setup"
  echo "========================================"
  echo ""

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
