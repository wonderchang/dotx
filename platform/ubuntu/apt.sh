#!/usr/bin/env bash
# platform/ubuntu/apt.sh
# Update APT and install base prerequisites on Ubuntu

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/apt-common.sh"

update_apt() {
  echo "=== Updating APT ==="

  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would run: sudo apt-get update"
  else
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
    echo "✓ APT updated"
  fi
  echo ""
}

# Base tools that every component relies on, like Homebrew on macOS:
#   curl - bash (bash-git-prompt), vim (vim-plug), nvm, pyenv, uv, rust
#   git  - tmux (powerline fonts), vim (plugins), pyenv, nvm
# They are never removed. Anything only some components need (build-essential
# for rust and pyenv, pyenv's libraries, unzip, QEMU) is declared by those
# components through install_apt_packages_for and reference-counted there.
PREREQUISITES=(curl git)

install_prerequisites() {
  echo "=== Base Prerequisites ==="

  local package
  for package in "${PREREQUISITES[@]}"; do
    install_apt_package "$package"
  done
  echo ""
}

# Execute
update_apt
install_prerequisites
