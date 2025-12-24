#!/usr/bin/env bash
# platform/macos/homebrew.sh
# Homebrew installation for macOS
#
# Usage:
#   bash homebrew.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Helper Functions
# ============================================================================

check_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: This script is for macOS only"
    exit 1
  fi
}

# ============================================================================
# Mode: Install
# ============================================================================

install_homebrew() {
  echo "=== Homebrew Installation ==="

  # Check if Homebrew is already installed
  if command -v brew &> /dev/null; then
    BREW_VERSION=$(brew --version | head -1)
    echo "✓ Homebrew already installed: $BREW_VERSION"
    echo ""
    return 0
  fi

  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Homebrew not found - would install via official installer"
    echo "[DRY-RUN] Would run: curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    echo ""
    return 0
  fi

  echo "Homebrew not found - installing..."
  echo ""

  # Download and run the official Homebrew installation script
  echo "Running official Homebrew installer..."
  echo "You may be prompted for your password."
  echo ""

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Verify installation
  if command -v brew &> /dev/null; then
    BREW_VERSION=$(brew --version | head -1)
    echo ""
    echo "✓ Homebrew successfully installed: $BREW_VERSION"
    echo ""

    # Run brew doctor to check installation
    echo "Running brew doctor to verify installation..."
    brew doctor || echo "⚠ Some issues detected, but Homebrew is installed"
    echo ""
  else
    echo ""
    echo "ERROR: Homebrew installation failed"
    echo "Please visit https://brew.sh for manual installation instructions"
    exit 1
  fi

  echo "✓ Homebrew installation complete!"
  echo ""
}

# ============================================================================
# Main
# ============================================================================

# Check platform first
check_macos

# Install Homebrew
install_homebrew
