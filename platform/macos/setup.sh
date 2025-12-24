#!/usr/bin/env bash
# platform/macos/setup.sh
# macOS-specific setup orchestrator

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities for bash setup
source "$PROJECT_ROOT/utils/symlink.sh"

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
    echo "Installing $package..."
    brew install "$package"
    echo "✓ $package installed"
  fi
}

uninstall_brew_package() {
  local package="$1"

  if brew list "$package" &>/dev/null; then
    echo "Uninstalling $package..."
    brew uninstall "$package"
    echo "✓ $package uninstalled"
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
    echo ""
  fi

  if should_install_component "bash"; then
    echo "=== Bash ==="
    bash "$PROJECT_ROOT/common/bash/setup.sh" install

    # Setup platform-specific bash configuration
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
    echo "=== Pyenv ==="
    install_brew_package "pyenv"
    echo "✓ pyenv installed (no configuration needed)"
    echo ""
  fi

  if should_install_component "pipx"; then
    echo "=== Pipx ==="
    install_brew_package "pipx"
    echo "✓ pipx installed (no configuration needed)"
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
    bash "$PROJECT_ROOT/common/tmux/setup.sh" uninstall
    uninstall_brew_package "tmux"
    echo ""
  fi

  if should_install_component "bash"; then
    echo "=== Bash ==="
    bash "$PROJECT_ROOT/common/bash/setup.sh" uninstall

    # Remove platform-specific bash configuration
    echo "=== macOS-Specific Bash Uninstall ==="
    remove_symlink "$HOME/.bashrc.local"
    echo ""
  fi

  if should_install_component "nvm"; then
    echo "=== NVM ==="
    bash "$PROJECT_ROOT/common/nvm/setup.sh" uninstall
    echo ""
  fi

  if should_install_component "pyenv"; then
    echo "=== Pyenv ==="
    uninstall_brew_package "pyenv"
    echo ""
  fi

  if should_install_component "pipx"; then
    echo "=== Pipx ==="
    uninstall_brew_package "pipx"
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
