#!/usr/bin/env bash
# common/uv/setup.sh
# Platform-independent uv setup (installation)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Remove auto-added env line from a shell config file
# Args: $1 = file path (e.g., ~/.bashrc)
cleanup_env_line() {
  local file_path="$1"
  local file_name=$(basename "$file_path")

  # Resolve symlink to actual file
  if [ -L "$file_path" ]; then
    file_path=$(readlink -f "$file_path" 2>/dev/null || readlink "$file_path" 2>/dev/null || echo "$file_path")
  fi

  if [ -f "$file_path" ] && grep -q '^\. "\$HOME/\.local/bin/env"' "$file_path"; then
    # cp -p first so the rewritten file keeps the original mode
    cp -p "$file_path" "$file_path.tmp"
    grep -v '^\. "\$HOME/\.local/bin/env"' "$file_path" > "$file_path.tmp" || true
    mv -f "$file_path.tmp" "$file_path"
    echo "✓ Cleaned up auto-added line from $file_name"
  fi
}

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
    echo "[DRY-RUN] Would remove auto-added line from shell configs"
  else
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    echo "✓ uv installed"

    # Remove the line that uv installer automatically adds to shell configs
    # We don't need it because ~/.local/bin is already in PATH
    cleanup_env_line "$HOME/.bashrc"
    cleanup_env_line "$HOME/.bash_profile"
    cleanup_env_line "$HOME/.profile"
  fi

  echo ""
  echo "Note: uv is installed to ~/.local/bin/uv"
  echo "      ~/.local/bin is already in PATH (shared with pipx)"
  echo ""
}

uninstall_uv_setup() {
  echo "=== uv Uninstall ==="

  # Check if any uv files exist (don't rely on PATH)
  if [ ! -f "$HOME/.local/bin/uv" ] && [ ! -f "$HOME/.local/bin/uvx" ] && [ ! -f "$HOME/.local/bin/env" ]; then
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

  # Remove uvx binary (installed alongside uv)
  if [ -f "$HOME/.local/bin/uvx" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would remove uvx binary: ~/.local/bin/uvx"
    else
      rm -f "$HOME/.local/bin/uvx"
      echo "  Removed uvx binary: ~/.local/bin/uvx"
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
