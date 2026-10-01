#!/usr/bin/env bash
# common/vim/setup.sh
# Platform-independent vim setup (symlinks, vim-plug, and plugins)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities
source "$PROJECT_ROOT/utils/symlink.sh"

VIM_PLUG="$HOME/.vim/autoload/plug.vim"
VIM_PLUG_VERSION="0.14.0"

install_vim_setup() {
  echo "=== Vim Setup ==="

  # 1. Create symlink for vimrc
  echo "Linking vim configuration..."
  create_symlink "$SCRIPT_DIR/.vimrc" "$HOME/.vimrc"
  echo "✓ Vim configuration linked"
  echo ""

  # 2. Install vim-plug (if vim is available)
  if ! command -v vim &>/dev/null; then
    echo "⚠ Vim not found - skipping plugin setup"
    return 0
  fi

  echo "=== Installing Vim Plugins ==="

  # Install vim-plug if not present
  if [ ! -f "$VIM_PLUG" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would install vim-plug from GitHub"
    else
      echo "Installing vim-plug..."
      curl -fSL --progress-bar -o "$VIM_PLUG" --create-dirs \
        "https://raw.githubusercontent.com/junegunn/vim-plug/${VIM_PLUG_VERSION}/plug.vim"
      echo "✓ vim-plug installed"
    fi
  else
    echo "✓ vim-plug already installed"
  fi

  # 3. Install plugins
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would install vim plugins via PlugInstall"
  else
    echo "Installing vim plugins..."
    # Headless Ex mode (-es): no full-screen UI, no "Press ENTER" prompts.
    # --sync blocks until every plugin is installed before qa! runs.
    vim -es -u "$HOME/.vimrc" -i NONE -c 'PlugInstall --sync' -c 'qa!' || true
    echo "✓ Vim plugins installed"
  fi
  echo ""
}

uninstall_vim_setup() {
  echo "=== Vim Uninstall ==="

  # 1. Remove symlink
  remove_symlink "$HOME/.vimrc"

  # 2. Remove vim-plug and plugins
  if [ -d "$HOME/.vim" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      [ -f "$HOME/.vim/autoload/plug.vim" ] && echo "  [DRY-RUN] Would remove vim-plug"
      [ -d "$HOME/.vim/plugged" ] && echo "  [DRY-RUN] Would remove vim plugins"
      [ -d "$HOME/.vim/autoload" ] && echo "  [DRY-RUN] Would clean up autoload directory"
      [ -d "$HOME/.vim" ] && echo "  [DRY-RUN] Would clean up .vim directory"
    else
      [ -f "$HOME/.vim/autoload/plug.vim" ] && rm -f "$HOME/.vim/autoload/plug.vim" && echo "  Removed vim-plug"
      [ -d "$HOME/.vim/plugged" ] && rm -rf "$HOME/.vim/plugged" && echo "  Removed vim plugins"

      # Clean up empty directories
      [ -d "$HOME/.vim/autoload" ] && [ -z "$(ls -A "$HOME/.vim/autoload")" ] && rmdir "$HOME/.vim/autoload"
      [ -d "$HOME/.vim" ] && [ -z "$(ls -A "$HOME/.vim")" ] && rmdir "$HOME/.vim"
    fi
  fi

  echo ""
}

# Execute based on mode
MODE="${1:-install}"

case "$MODE" in
  install)
    install_vim_setup
    ;;
  uninstall)
    uninstall_vim_setup
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
