#!/usr/bin/env bash
# platform/ubuntu/lima.sh
# Lima (Linux virtual machines, https://lima-vm.io) from the official GitHub
# release tarball, into the user's home; QEMU from APT
#
# Usage:
#   bash lima.sh install
#   bash lima.sh uninstall
#
# Notes:
#   - Follows https://lima-vm.io/docs/installation/ (tarball into a prefix),
#     but the prefix is ~/.local/lima so the whole install is one directory;
#     bin/* is symlinked into ~/.local/bin (already on PATH via .bashrc).
#     Lima locates share/lima relative to the real binary, so symlinks work.
#   - On Linux hosts Lima runs on QEMU: qemu-system-x86 (x86_64) or
#     qemu-system-arm (aarch64) plus qemu-utils, installed via APT (sudo is
#     cached by setup.sh); uninstall removes the ones this script installed
#     and leaves pre-existing ones alone.
#   - ~/.lima (VM instances and disks) is never touched.
#   - Completion is wired up in common/bash/.bashrc via `limactl completion`.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/apt-common.sh"

PREFIX="$HOME/.local/lima"
BIN_DIR="$HOME/.local/bin"

qemu_packages() {
  case "$(uname -m)" in
    x86_64)        echo "qemu-system-x86 qemu-utils" ;;
    aarch64|arm64) echo "qemu-system-arm qemu-utils" ;;
    *)             echo "" ;;
  esac
}

# Latest release tag, taken from the redirect of /releases/latest (no API
# rate limit involved)
latest_tag() {
  curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/lima-vm/lima/releases/latest \
    | sed 's#.*/tag/##'
}

install_lima() {
  echo "=== Lima ==="

  if [ -x "$BIN_DIR/limactl" ]; then
    echo "✓ lima already installed: $("$BIN_DIR/limactl" --version 2>&1)"
    return 0
  fi

  local packages arch
  packages=$(qemu_packages)
  # Release assets are named Linux-x86_64 / Linux-aarch64
  case "$(uname -m)" in
    arm64) arch=aarch64 ;;
    *)     arch=$(uname -m) ;;
  esac
  if [ -z "$packages" ]; then
    echo "  ✗ Unsupported architecture for Lima on Linux: $arch"
    return 1
  fi

  if [ "${DRY_RUN:-false}" = "true" ]; then
    # shellcheck disable=SC2086
    install_apt_packages_for lima $packages
    echo "[DRY-RUN] Would download the latest lima-<version>-Linux-$arch.tar.gz from GitHub"
    echo "[DRY-RUN] Would extract it to $PREFIX and symlink bin/* into $BIN_DIR"
    return 0
  fi

  echo "Installing QEMU..."
  # shellcheck disable=SC2086  # word splitting of the package list is intended
  install_apt_packages_for lima $packages

  local tag version url
  tag=$(latest_tag)
  version="${tag#v}"
  url="https://github.com/lima-vm/lima/releases/download/${tag}/lima-${version}-Linux-${arch}.tar.gz"

  echo "Downloading Lima $version..."
  mkdir -p "$PREFIX" "$BIN_DIR"
  curl -fSL --progress-bar "$url" | tar xz -C "$PREFIX"

  local bin
  for bin in "$PREFIX"/bin/*; do
    ln -sfn "$bin" "$BIN_DIR/$(basename "$bin")"
  done
  echo "✓ lima installed: $("$BIN_DIR/limactl" --version 2>&1)"
}

uninstall_lima() {
  echo "=== Lima Uninstall ==="

  if [ ! -d "$PREFIX" ] && [ ! -L "$BIN_DIR/limactl" ]; then
    echo "✓ lima not installed"
    return 0
  fi

  if [ -x "$BIN_DIR/limactl" ] && [ -n "$("$BIN_DIR/limactl" list -q 2>/dev/null)" ]; then
    echo "  ⚠ Lima instances exist in ~/.lima; they are kept. Stop running ones first:"
    echo "    limactl list; limactl stop <name>"
  fi

  # Symlinks in ~/.local/bin that point into the prefix, then the prefix itself
  local link
  for link in "$BIN_DIR"/*; do
    if [ -L "$link" ] && [[ "$(readlink "$link")" == "$PREFIX/"* ]]; then
      if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "  [DRY-RUN] Would remove symlink $link"
      else
        rm -f "$link"
        echo "  Removed symlink $link"
      fi
    fi
  done
  if [ -d "$PREFIX" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would remove $PREFIX"
    else
      rm -rf "$PREFIX"
      echo "  Removed $PREFIX"
    fi
  fi

  uninstall_apt_packages_for lima

  if [ -d "$HOME/.lima" ]; then
    echo "  Note: ~/.lima (VM instances, disks) is kept"
  fi
}

# Execute based on mode
MODE="${1:-install}"

case "$MODE" in
  install)
    install_lima
    ;;
  uninstall)
    uninstall_lima
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
