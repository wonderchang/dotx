#!/usr/bin/env bash
# common/git/setup.sh
# Platform-independent git setup (symlinks)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities
source "$PROJECT_ROOT/utils/symlink.sh"

# platform/<os>/.gitconfig.<os>: the machine-specific part (signing key,
# credential helper, SSH rewrite), included by .gitconfig as
# ~/.gitconfig.local. Linked in the full profile only.
case "$OSTYPE" in
  darwin*) PLATFORM_GITCONFIG="$PROJECT_ROOT/platform/macos/.gitconfig.macos" ;;
  *)       PLATFORM_GITCONFIG="$PROJECT_ROOT/platform/ubuntu/.gitconfig.ubuntu" ;;
esac

install_git_setup() {
  echo "=== Git Setup ==="

  echo "Linking git configuration..."
  create_symlink "$SCRIPT_DIR/.gitconfig" "$HOME/.gitconfig"
  if [ "${DOTX_PROFILE:-full}" = "minimal" ]; then
    # No signing key, no SSH rewrite: plain HTTPS git that works anywhere
    remove_symlink "$HOME/.gitconfig.local"
    echo "  ✓ No ~/.gitconfig.local (minimal profile: no signing, HTTPS to GitHub)"
  else
    create_symlink "$PLATFORM_GITCONFIG" "$HOME/.gitconfig.local"
  fi
  echo "✓ Git configuration linked"
  echo ""
}

uninstall_git_setup() {
  echo "=== Git Uninstall ==="

  remove_symlink "$HOME/.gitconfig.local"
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
