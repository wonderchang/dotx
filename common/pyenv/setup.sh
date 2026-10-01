#!/usr/bin/env bash
# common/pyenv/setup.sh
# Platform-independent pyenv (Python Version Manager) setup

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PYENV_ROOT="$HOME/.pyenv"

install_pyenv_setup() {
  echo "=== pyenv Setup ==="

  # Check if pyenv is already installed
  if [ -d "$PYENV_ROOT" ]; then
    echo "✓ pyenv already installed at $PYENV_ROOT"
  else
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would install pyenv from GitHub using pyenv-installer"
    else
      echo "Installing pyenv..."

      # Install pyenv using pyenv-installer (official method)
      curl -fsSL https://pyenv.run | bash

      echo "✓ pyenv installed"
    fi
  fi

  echo ""
}

uninstall_pyenv_setup() {
  echo "=== pyenv Uninstall ==="

  # Remove pyenv directory
  if [ -d "$PYENV_ROOT" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would remove pyenv directory: $PYENV_ROOT"
    else
      rm -rf "$PYENV_ROOT"
      echo "  Removed pyenv directory: $PYENV_ROOT"
    fi
  else
    echo "✓ pyenv not installed"
  fi

  echo ""
}

# Execute based on mode
MODE="${1:-install}"

case "$MODE" in
  install)
    install_pyenv_setup
    ;;
  uninstall)
    uninstall_pyenv_setup
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
