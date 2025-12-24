#!/usr/bin/env bash
# scripts/utils/detect.sh
# Platform and package manager detection utilities
# Supports: macOS and Ubuntu/Debian Linux only
#
# Usage:
#   source scripts/utils/detect.sh
#   PLATFORM=$(detect_platform)
#   PKG_MGR=$(detect_package_manager "$PLATFORM")

# ============================================================================
# Platform Detection
# ============================================================================

detect_platform() {
  case "$(uname -s)" in
    Darwin*)
      echo "macos"
      ;;
    Linux*)
      if command -v apt-get &>/dev/null; then
        echo "ubuntu"
      else
        echo "unsupported"
        echo "ERROR: Only Ubuntu/Debian Linux is supported" >&2
        exit 1
      fi
      ;;
    *)
      echo "unsupported"
      echo "ERROR: Only macOS and Ubuntu are supported" >&2
      exit 1
      ;;
  esac
}

detect_package_manager() {
  local platform="$1"

  case "$platform" in
    macos)
      echo "brew"
      ;;
    ubuntu)
      echo "apt"
      ;;
    *)
      echo "unknown"
      echo "ERROR: Unsupported platform: $platform" >&2
      exit 1
      ;;
  esac
}
