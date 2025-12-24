#!/usr/bin/env bash
# common/nvm/setup.sh
# Platform-independent nvm (Node Version Manager) setup

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

NVM_VERSION="0.40.1"
NVM_DIR="$HOME/.nvm"

install_nvm_setup() {
  echo "=== NVM Setup ==="

  # Check if nvm is already installed
  if [ -d "$NVM_DIR" ]; then
    echo "✓ nvm already installed at $NVM_DIR"
  else
    echo "Installing nvm ${NVM_VERSION}..."

    # Download and install nvm
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash

    echo "✓ nvm installed"
  fi

  echo ""
}

uninstall_nvm_setup() {
  echo "=== NVM Uninstall ==="

  # Remove nvm directory
  if [ -d "$NVM_DIR" ]; then
    rm -rf "$NVM_DIR"
    echo "  Removed nvm directory"
  fi

  echo ""
}

# Execute based on mode
MODE="${1:-install}"

case "$MODE" in
  install)
    install_nvm_setup
    ;;
  uninstall)
    uninstall_nvm_setup
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
