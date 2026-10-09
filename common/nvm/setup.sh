#!/usr/bin/env bash
# common/nvm/setup.sh
# Platform-independent nvm (Node Version Manager) setup

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/utils/marker.sh"

NVM_VERSION="0.40.1"
NVM_DIR="$HOME/.nvm"

install_nvm_setup() {
  echo "=== NVM Setup ==="

  # Check if nvm is already installed
  if [ -d "$NVM_DIR" ]; then
    echo "✓ nvm already installed at $NVM_DIR"
  else
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would install nvm ${NVM_VERSION} from GitHub"
    else
      echo "Installing nvm ${NVM_VERSION}..."

      # Download and install nvm
      curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash

      # A failed download pipes nothing into bash, so check the result
      if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        echo "✗ nvm installation failed: $NVM_DIR/nvm.sh missing"
        exit 1
      fi
      mark_installed nvm
      echo "✓ nvm installed"
    fi
  fi

  echo ""
}

uninstall_nvm_setup() {
  echo "=== NVM Uninstall ==="

  # Remove nvm (and every Node version in it) only when dotx installed it
  if [ -d "$NVM_DIR" ] && ! is_marked_installed nvm; then
    echo "  Note: nvm was installed before dotx; kept (remove with: rm -rf ~/.nvm)"
  elif [ -d "$NVM_DIR" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would remove nvm directory"
    else
      rm -rf "$NVM_DIR"
      unmark_installed nvm
      echo "  Removed nvm directory"
    fi
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
