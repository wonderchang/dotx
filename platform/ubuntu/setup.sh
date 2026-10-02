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
source "$SCRIPT_DIR/apt-common.sh"               # install_apt_package() and friends

# Component list to install/uninstall
COMPONENTS=()

# Libraries pyenv needs to build a Python, from
# https://github.com/pyenv/pyenv/wiki#suggested-build-environment (Ubuntu);
# build-essential, curl and git are base prerequisites (apt.sh). The wiki's
# libncursesw5-dev is only a transitional name for libncurses-dev on current
# Ubuntu (APT substitutes it, and the substituted name is what dpkg knows).
PYENV_BUILD_DEPS=(libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev
  libncurses-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev)

# ============================================================================
# Package Management Helpers
# ============================================================================


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
    install_apt_packages_for vim vim
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
    install_apt_packages_for tmux tmux
    bash "$PROJECT_ROOT/common/tmux/setup.sh" install
    echo ""
  fi

  if should_install_component "htop"; then
    echo "=== htop ==="
    install_apt_packages_for htop htop
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
    echo "=== pyenv Build Dependencies ==="
    install_apt_packages_for pyenv "${PYENV_BUILD_DEPS[@]}"
    echo ""
    bash "$PROJECT_ROOT/common/pyenv/setup.sh" install
    echo ""
  fi

  if should_install_component "pipx"; then
    echo "=== pipx ==="
    # Package manager install: `pip install --user` is blocked by PEP 668
    # on Homebrew Python and Ubuntu 23.04+ / Debian 12.
    # ~/.local/bin is already on PATH via .bashrc, so no `pipx ensurepath`.
    install_apt_packages_for pipx pipx
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
    uninstall_apt_packages_for vim
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
    uninstall_apt_packages_for tmux
    echo ""
  fi

  if should_install_component "htop"; then
    echo "=== htop ==="
    uninstall_apt_packages_for htop
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
    echo "=== pyenv Build Dependencies Uninstall ==="
    uninstall_apt_packages_for pyenv
    echo ""
  fi

  if should_install_component "pipx"; then
    echo "=== pipx ==="
    uninstall_apt_packages_for pipx
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
