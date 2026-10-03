#!/usr/bin/env bash
# common/tmux/setup.sh
# Platform-independent tmux setup (symlinks)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# powerline/fonts installs into ~/Library/Fonts on macOS and
# ~/.local/share/fonts on Linux; one font from the set marks the whole install
# so re-runs skip the 20 MB clone and uninstall skips it when nothing is there.
if [[ "$OSTYPE" == "darwin"* ]]; then
  POWERLINE_FONT_DIR="$HOME/Library/Fonts"
else
  POWERLINE_FONT_DIR="$HOME/.local/share/fonts"
fi
POWERLINE_MARKER_FONT="$POWERLINE_FONT_DIR/Source Code Pro for Powerline.otf"

# Source utilities
source "$PROJECT_ROOT/utils/symlink.sh"

install_tmux_setup() {
  echo "=== Tmux Setup ==="

  # Create symlinks for tmux configs
  echo "Linking tmux configuration..."
  create_symlink "$SCRIPT_DIR/.tmux.conf" "$HOME/.tmux.conf"
  create_symlink "$SCRIPT_DIR/.tmux.conf.local" "$HOME/.tmux.conf.local"
  # Minimal profile: overlay that turns the powerline theme into the plain
  # one (sourced after .tmux.conf.local). Full profile: make sure it is gone.
  if [ "${DOTX_PROFILE:-full}" = "minimal" ]; then
    create_symlink "$SCRIPT_DIR/.tmux.conf.plain" "$HOME/.tmux.conf.plain"
  else
    remove_symlink "$HOME/.tmux.conf.plain"
  fi
  echo "✓ Tmux configuration linked"

  # Install powerline fonts (key dependency for the powerline theme)
  echo ""
  if [ "${DOTX_PROFILE:-full}" = "minimal" ]; then
    echo "✓ Powerline fonts skipped (minimal profile uses the plain theme)"
  elif [ -f "$POWERLINE_MARKER_FONT" ]; then
    echo "✓ Powerline fonts already installed"
  elif [ "${DRY_RUN:-false}" = "true" ]; then
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
  remove_symlink "$HOME/.tmux.conf.plain"

  # Uninstall powerline fonts
  echo ""
  if [ ! -f "$POWERLINE_MARKER_FONT" ]; then
    echo "✓ Powerline fonts not installed"
  elif [ "${DRY_RUN:-false}" = "true" ]; then
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
