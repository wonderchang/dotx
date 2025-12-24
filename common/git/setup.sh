#!/usr/bin/env bash
# common/git/setup.sh
# Platform-independent git setup (symlinks)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities
source "$PROJECT_ROOT/utils/symlink.sh"

install_git_setup() {
  echo "=== Git Setup ==="

  # Create symlink for gitconfig
  echo "Linking git configuration..."
  create_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig"
  echo "✓ Git configuration linked"
  echo ""
}

uninstall_git_setup() {
  echo "=== Git Uninstall ==="

  # Remove symlink
  remove_symlink "$HOME/.gitconfig"
  echo ""
}

# Execute based on mode
MODE="${1:-install}"

case "$MODE" in
  install)
    install_git_setup
    ;;
  uninstall)
    uninstall_git_setup
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
