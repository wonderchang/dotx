#!/usr/bin/env bash
# platform/ubuntu/apt.sh
# Update APT and install base prerequisites on Ubuntu

set -eu

update_apt() {
  echo "=== Updating APT ==="

  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would run: sudo apt-get update"
  else
    sudo apt-get update
    echo "✓ APT updated"
  fi
  echo ""
}

# Base tools that several components need, like Homebrew on macOS:
#   curl - bash (bash-git-prompt), vim (vim-plug), nvm, pyenv, uv, rust
#   git  - tmux (powerline fonts), vim (plugins), pyenv, nvm
PREREQUISITES=(curl git)

install_prerequisites() {
  echo "=== Base Prerequisites ==="

  local package
  for package in "${PREREQUISITES[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
      echo "✓ $package already installed"
    elif [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would install $package via APT"
    else
      echo "Installing $package..."
      sudo apt-get install -y "$package"
      echo "✓ $package installed"
    fi
  done
  echo ""
}

# Execute
update_apt
install_prerequisites
