#!/usr/bin/env bash
# bootstrap.sh
# Main entry point for dotfiles setup
#
# Usage:
#   ./bootstrap.sh [--install|--uninstall] [--dry-run] [components...]
#
# Modes:
#   --install   Install dotfiles and packages (default)
#   --uninstall Remove dotfiles and packages
#   --dry-run   Preview changes without applying them
#
# Components:
#   basic ones (vim, git, tmux, htop, bash, nvm, pyenv, pipx, uv, rust) are installed
#   by default; optional ones (gcloud, aws, lima, docker) only when named. `all` = basic + optional.
#   See utils/components.sh.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "$SCRIPT_DIR/utils/detect.sh"
source "$SCRIPT_DIR/utils/components.sh"

# dotx and the installers it runs (vim-plug, nvm, pyenv, powerline fonts)
# clone public repos over HTTPS. The user's ~/.gitconfig (linked by the git
# component) rewrites https://github.com/ to git@github.com:, which fails on a
# fresh machine without a GitHub SSH key. Hide the global config from every
# git run by this script so those clones stay on HTTPS. Needs git >= 2.32.
export GIT_CONFIG_GLOBAL=/dev/null

# ============================================================================
# Main
# ============================================================================

main() {
  local MODE="$1"
  local DRY_RUN="$2"
  shift 2
  local COMPONENTS=("$@")

  # Detect platform
  PLATFORM=$(detect_platform)

  echo ""
  echo "========================================"
  echo "  Dotfiles Bootstrap"
  echo "========================================"
  echo "  Platform: $PLATFORM"
  echo "  Mode: $MODE"
  if [ "$DRY_RUN" = "true" ]; then
    echo "  Dry Run: ENABLED (no changes will be made)"
  fi
  echo "  Components: $(describe_components)"
  echo "========================================"
  echo ""

  # Export DRY_RUN for child scripts
  export DRY_RUN

  # Delegate to platform-specific setup
  case "$PLATFORM" in
    macos)
      bash "$SCRIPT_DIR/platform/macos/setup.sh" "$MODE" ${COMPONENTS[@]+"${COMPONENTS[@]}"}
      ;;
    ubuntu)
      bash "$SCRIPT_DIR/platform/ubuntu/setup.sh" "$MODE" ${COMPONENTS[@]+"${COMPONENTS[@]}"}
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
DRY_RUN="false"
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
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--install|--uninstall] [--dry-run] [components...]"
      echo ""
      echo "Modes:"
      echo "  --install   Install dotfiles and packages (default)"
      echo "  --uninstall Remove dotfiles and packages"
      echo "  --dry-run   Preview changes without applying them"
      echo ""
      echo "Basic components (installed when none are given):"
      echo "  vim         Vim editor with vim-plug"
      echo "  git         Git configuration"
      echo "  tmux        Tmux terminal multiplexer"
      echo "  htop        Interactive process viewer"
      echo "  bash        Bash configuration with bash-git-prompt"
      echo "  nvm         Node Version Manager"
      echo "  pyenv       Python version manager"
      echo "  pipx        Python application installer"
      echo "  uv          Python package and project manager"
      echo "  rust        Rust programming language (via rustup)"
      echo ""
      echo "Optional components (only when named explicitly):"
      echo "  gcloud      Google Cloud CLI (gcloud, gsutil, bq)"
      echo "  aws         AWS CLI v2"
      echo "  lima        Lima: Linux virtual machines"
      echo "  docker      Docker (colima on macOS, Docker Engine on Ubuntu)"
      echo ""
      echo "Selection keywords:"
      echo "  basic       The basic components (same as giving none)"
      echo "  all         Basic + optional components"
      echo ""
      echo "Examples:"
      echo "  $0                         # Install the basic components"
      echo "  $0 --dry-run               # Preview that"
      echo "  $0 gcloud                  # Install only gcloud"
      echo "  $0 basic gcloud            # Basic components plus gcloud"
      echo "  $0 all                     # Everything, including optional"
      echo "  $0 --install vim git       # Install only vim and git"
      echo "  $0 --dry-run --install vim # Preview vim installation"
      echo "  $0 --uninstall vim         # Uninstall only vim"
      echo "  $0 --uninstall             # Uninstall the basic components"
      echo "  $0 --uninstall all         # Uninstall everything, including optional"
      exit 0
      ;;
    *)
      if is_valid_component "$1"; then
        COMPONENTS+=("$1")
        shift
      else
        echo "Unknown option or component: $1"
        echo "Usage: $0 [--install|--uninstall] [--dry-run] [components...]"
        echo "Run '$0 --help' for more information"
        exit 1
      fi
      ;;
  esac
done

# Execute
main "$MODE" "$DRY_RUN" ${COMPONENTS[@]+"${COMPONENTS[@]}"}
