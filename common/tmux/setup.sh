#!/usr/bin/env bash
# common/tmux/setup.sh
# Platform-independent tmux setup (symlinks)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities
source "$PROJECT_ROOT/utils/symlink.sh"

install_tmux_setup() {
  echo "=== Tmux Setup ==="

  # Create symlinks for tmux configs
  echo "Linking tmux configuration..."
  create_symlink "$SCRIPT_DIR/.tmux.conf" "$HOME/.tmux.conf"
  create_symlink "$SCRIPT_DIR/.tmux.conf.local" "$HOME/.tmux.conf.local"
  echo "✓ Tmux configuration linked"

  # Install powerline fonts (key dependency for tmux)
  echo ""
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would install powerline fonts from GitHub"
  else
    echo "Installing powerline fonts..."
    local tmp_dir=$(mktemp -d)
    git clone https://github.com/powerline/fonts.git "$tmp_dir/fonts"
    cd "$tmp_dir/fonts" && ./install.sh
    cd "$HOME"
    rm -rf "$tmp_dir"
    echo "✓ Powerline fonts installed"
  fi
  echo ""
}

uninstall_tmux_setup() {
  echo "=== Tmux Uninstall ==="

  # Remove symlinks
  remove_symlink "$HOME/.tmux.conf"
  remove_symlink "$HOME/.tmux.conf.local"

  # Uninstall powerline fonts
  echo ""
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would uninstall powerline fonts"
  else
    echo "Uninstalling powerline fonts..."
    local tmp_dir=$(mktemp -d)
    git clone https://github.com/powerline/fonts.git "$tmp_dir/fonts"
    cd "$tmp_dir/fonts" && ./uninstall.sh
    cd "$HOME"
    rm -rf "$tmp_dir"
    echo "✓ Powerline fonts uninstalled"
  fi
  echo ""
}

# Execute based on mode
MODE="${1:-install}"

case "$MODE" in
  install)
    install_tmux_setup
    ;;
  uninstall)
    uninstall_tmux_setup
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
