#!/usr/bin/env bash
# bootstrap.sh
# Main entry point for dotfiles setup
#
# Usage:
#   ./bootstrap.sh [--install|--uninstall] [components...]
#
# Modes:
#   --install   Install dotfiles and packages (default)
#   --uninstall Remove dotfiles and packages
#
# Components:
#   vim, git, tmux, bash, nvm (or 'all' for everything)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "$SCRIPT_DIR/utils/detect.sh"

# ============================================================================
# Main
# ============================================================================

main() {
  local MODE="$1"
  shift
  local COMPONENTS=("$@")

  # Detect platform
  PLATFORM=$(detect_platform)

  echo ""
  echo "========================================"
  echo "  Dotfiles Bootstrap"
  echo "========================================"
  echo "  Platform: $PLATFORM"
  echo "  Mode: $MODE"
  if [ ${#COMPONENTS[@]} -gt 0 ]; then
    echo "  Components: ${COMPONENTS[*]}"
  else
    echo "  Components: all"
  fi
  echo "========================================"
  echo ""

  # Delegate to platform-specific setup
  case "$PLATFORM" in
    macos)
      bash "$SCRIPT_DIR/platform/macos/setup.sh" "$MODE" "${COMPONENTS[@]}"
      ;;
    ubuntu)
      bash "$SCRIPT_DIR/platform/ubuntu/setup.sh" "$MODE" "${COMPONENTS[@]}"
      ;;
    *)
      echo "ERROR: Unsupported platform: $PLATFORM"
      echo "Supported platforms: macOS, Ubuntu"
      exit 1
      ;;
  esac
}

# ============================================================================
# Command Line Interface
# ============================================================================

MODE="install"
COMPONENTS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --install)
      MODE="install"
      shift
      ;;
    --uninstall)
      MODE="uninstall"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--install|--uninstall] [components...]"
      echo ""
      echo "Modes:"
      echo "  --install   Install dotfiles and packages (default)"
      echo "  --uninstall Remove dotfiles and packages"
      echo ""
      echo "Components (optional):"
      echo "  vim         Vim editor with vim-plug"
      echo "  git         Git configuration"
      echo "  tmux        Tmux terminal multiplexer"
      echo "  bash        Bash configuration with bash-git-prompt"
      echo "  nvm         Node Version Manager"
      echo "  pyenv       Python version manager (package only)"
      echo "  pipx        Python application installer (package only)"
      echo "  all         All components (default if none specified)"
      echo ""
      echo "Examples:"
      echo "  $0                    # Install everything"
      echo "  $0 --install vim git  # Install only vim and git"
      echo "  $0 --install bash     # Install only bash"
      echo "  $0 --install pyenv    # Install only pyenv"
      echo "  $0 --uninstall vim    # Uninstall only vim"
      echo "  $0 --uninstall        # Uninstall everything"
      exit 0
      ;;
    vim|git|tmux|bash|nvm|pyenv|pipx|all)
      COMPONENTS+=("$1")
      shift
      ;;
    *)
      echo "Unknown option or component: $1"
      echo "Usage: $0 [--install|--uninstall] [components...]"
      echo "Run '$0 --help' for more information"
      exit 1
      ;;
  esac
done

# Execute
main "$MODE" "${COMPONENTS[@]}"
