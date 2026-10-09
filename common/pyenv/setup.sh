#!/usr/bin/env bash
# common/pyenv/setup.sh
# Platform-independent pyenv (Python Version Manager) setup

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/utils/marker.sh"

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

      # A failed download pipes nothing into bash, so check the result
      if [ ! -x "$PYENV_ROOT/bin/pyenv" ]; then
        echo "✗ pyenv installation failed: $PYENV_ROOT/bin/pyenv missing"
        exit 1
      fi
      mark_installed pyenv
      echo "✓ pyenv installed"
    fi
  fi

  echo ""
}

uninstall_pyenv_setup() {
  echo "=== pyenv Uninstall ==="

  # Remove pyenv (and every Python version in it) only when dotx installed it
  if [ -d "$PYENV_ROOT" ] && ! is_marked_installed pyenv; then
    echo "  Note: pyenv was installed before dotx; kept (remove with: rm -rf ~/.pyenv)"
  elif [ -d "$PYENV_ROOT" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would remove pyenv directory: $PYENV_ROOT"
    else
      rm -rf "$PYENV_ROOT"
      unmark_installed pyenv
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
