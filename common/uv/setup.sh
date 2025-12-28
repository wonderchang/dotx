#!/usr/bin/env bash
# common/uv/setup.sh
# Platform-independent uv setup (installation)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

install_uv_setup() {
  echo "=== uv Setup ==="

  # Check if uv is already installed
  if command -v uv &> /dev/null; then
    echo "✓ uv already installed: $(uv --version)"
    return 0
  fi

  # Install uv via official installer
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would download and install uv from https://astral.sh/uv/install.sh"
    echo "[DRY-RUN] Would remove auto-added line from ~/.bashrc"
  else
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    echo "✓ uv installed"

    # Remove the line that uv installer automatically adds to .bashrc
    # We don't need it because ~/.local/bin is already in PATH
    # Handle both regular files and symlinks (resolve to actual file)
    local bashrc_path="$HOME/.bashrc"
    if [ -L "$bashrc_path" ]; then
      # If it's a symlink, get the actual file path
      bashrc_path=$(readlink -f "$bashrc_path" 2>/dev/null || readlink "$bashrc_path" 2>/dev/null || echo "$HOME/.bashrc")
    fi

    if [ -f "$bashrc_path" ] && grep -q '^\. "\$HOME/\.local/bin/env"' "$bashrc_path"; then
      # Create a temporary file without the uv-added line
      grep -v '^\. "\$HOME/\.local/bin/env"' "$bashrc_path" > "$bashrc_path.tmp"
      mv "$bashrc_path.tmp" "$bashrc_path"
      echo "✓ Cleaned up auto-added line from .bashrc"
    fi
  fi

  echo ""
  echo "Note: uv is installed to ~/.local/bin/uv"
  echo "      ~/.local/bin is already in PATH (shared with pipx)"
  echo ""
}

uninstall_uv_setup() {
  echo "=== uv Uninstall ==="

  # Check if uv is installed
  if ! command -v uv &> /dev/null; then
    echo "✓ uv not installed"
    return 0
  fi

  # Remove uv binary
  if [ -f "$HOME/.local/bin/uv" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would remove uv binary: ~/.local/bin/uv"
    else
      rm -f "$HOME/.local/bin/uv"
      echo "  Removed uv binary: ~/.local/bin/uv"
    fi
  fi

  # Remove uv-created env file if it exists
  if [ -f "$HOME/.local/bin/env" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would remove uv env file: ~/.local/bin/env"
    else
      rm -f "$HOME/.local/bin/env"
      echo "  Removed uv env file: ~/.local/bin/env"
    fi
  fi
  echo ""
}

# Execute based on mode
MODE="${1:-install}"

case "$MODE" in
  install)
    install_uv_setup
    ;;
  uninstall)
    uninstall_uv_setup
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
