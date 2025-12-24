#!/usr/bin/env bash
# common/pipx/setup.sh
# Platform-independent pipx (Python Application Installer) setup

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PIPX_BIN="$HOME/.local/bin/pipx"

install_pipx_setup() {
  echo "=== pipx Setup ==="

  # Check if pipx is already installed
  if command -v pipx &>/dev/null || [ -f "$PIPX_BIN" ]; then
    echo "✓ pipx already installed"
  else
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would install pipx via pip"
    else
      echo "Installing pipx..."

      # Install pipx using pip (cross-platform method)
      python3 -m pip install --user pipx

      # Ensure pipx path is added to shell
      python3 -m pipx ensurepath

      echo "✓ pipx installed"
    fi
  fi

  echo ""
}

uninstall_pipx_setup() {
  echo "=== pipx Uninstall ==="

  # Check if pipx is installed
  if command -v pipx &>/dev/null || [ -f "$PIPX_BIN" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would uninstall pipx via pip"
    else
      echo "Uninstalling pipx..."
      python3 -m pip uninstall -y pipx
      echo "  Removed pipx"
    fi
  else
    echo "✓ pipx not installed"
  fi

  echo ""
}

# Execute based on mode
MODE="${1:-install}"

case "$MODE" in
  install)
    install_pipx_setup
    ;;
  uninstall)
    uninstall_pipx_setup
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
