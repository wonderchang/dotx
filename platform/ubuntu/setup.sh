#!/usr/bin/env bash
# platform/ubuntu/setup.sh
# Ubuntu-specific setup orchestrator

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities for bash setup
source "$PROJECT_ROOT/utils/symlink.sh"
source "$PROJECT_ROOT/utils/sudo.sh"
source "$PROJECT_ROOT/utils/components.sh"   # should_install_component()

# Component list to install/uninstall
COMPONENTS=()

# ============================================================================
# Package Management Helpers
# ============================================================================

install_apt_package() {
  local package="$1"

  if dpkg -l | grep -q "^ii  $package "; then
    echo "✓ $package already installed"
  else
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would install $package via APT"
    else
      echo "Installing $package..."
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"
      echo "✓ $package installed"
    fi
  fi
}

uninstall_apt_package() {
  local package="$1"

  if dpkg -l | grep -q "^ii  $package "; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would uninstall $package via APT"
    else
      echo "Uninstalling $package..."
      sudo apt-get remove -y "$package"
      echo "✓ $package uninstalled"
    fi
  else
    echo "✓ $package not installed"
  fi
}

install_ubuntu() {
  echo "========================================"
  echo "  Ubuntu Setup"
  echo "========================================"
  echo ""

  # 0. Ask for the password once; apt-get needs it throughout
  request_sudo "apt-get update / install"

  # 1. Update APT and install base prerequisites (curl, git)
  bash "$SCRIPT_DIR/apt.sh"

  # 2. Install tools with their packages
  if should_install_component "vim"; then
    echo "=== Vim ==="
    install_apt_package "vim"
    bash "$PROJECT_ROOT/common/vim/setup.sh" install
    echo ""
  fi

  if should_install_component "git"; then
    echo "=== Git ==="
    install_apt_package "git"
    bash "$PROJECT_ROOT/common/git/setup.sh" install
    echo ""
  fi

  if should_install_component "tmux"; then
    echo "=== Tmux ==="
    install_apt_package "tmux"
    bash "$PROJECT_ROOT/common/tmux/setup.sh" install
    echo ""
  fi

  if should_install_component "bash"; then
    echo "=== Bash ==="
    bash "$PROJECT_ROOT/common/bash/setup.sh" install

    # Setup platform-specific bash configuration
    echo "=== Ubuntu-Specific Bash Configuration ==="
    create_symlink "$SCRIPT_DIR/.bashrc.ubuntu" "$HOME/.bashrc.local"
    echo "✓ Ubuntu bash configuration linked"
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
    install_apt_package "pipx"
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
    bash "$SCRIPT_DIR/gcloud.sh" install
    echo ""
  fi

  if should_install_component "aws"; then
    bash "$SCRIPT_DIR/aws.sh" install
    echo ""
  fi

  if should_install_component "lima"; then
    bash "$SCRIPT_DIR/lima.sh" install
    echo ""
  fi

  echo "========================================"
  echo "  ✓ Ubuntu Setup Complete!"
  echo "========================================"
  echo ""
}

uninstall_ubuntu() {
  echo "========================================"
  echo "  Ubuntu Uninstall"
  echo "========================================"
  echo ""

  # 0. Ask for the password once; apt-get remove needs it
  request_sudo "apt-get remove"

  # 1. Uninstall tools with their packages
  if should_install_component "vim"; then
    echo "=== Vim ==="
    bash "$PROJECT_ROOT/common/vim/setup.sh" uninstall
    uninstall_apt_package "vim"
    echo ""
  fi

  if should_install_component "git"; then
    echo "=== Git ==="
    bash "$PROJECT_ROOT/common/git/setup.sh" uninstall
    # Note: Not uninstalling git (base prerequisite installed by apt.sh)
    echo ""
  fi

  if should_install_component "tmux"; then
    echo "=== Tmux ==="
    bash "$PROJECT_ROOT/common/tmux/setup.sh" uninstall
    uninstall_apt_package "tmux"
    echo ""
  fi

  if should_install_component "bash"; then
    echo "=== Bash ==="
    bash "$PROJECT_ROOT/common/bash/setup.sh" uninstall

    # Remove platform-specific bash configuration
    echo "=== Ubuntu-Specific Bash Uninstall ==="
    remove_symlink "$HOME/.bashrc.local"
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
    uninstall_apt_package "pipx"
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
    bash "$SCRIPT_DIR/gcloud.sh" uninstall
    echo ""
  fi

  if should_install_component "aws"; then
    bash "$SCRIPT_DIR/aws.sh" uninstall
    echo ""
  fi

  if should_install_component "lima"; then
    bash "$SCRIPT_DIR/lima.sh" uninstall
    echo ""
  fi

  echo "========================================"
  echo "  ✓ Ubuntu Uninstall Complete!"
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
    install_ubuntu
    ;;
  uninstall)
    uninstall_ubuntu
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
