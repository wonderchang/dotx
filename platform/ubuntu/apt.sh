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

# Base tools that several components need, like Homebrew on macOS:
#   curl            - bash (bash-git-prompt), vim (vim-plug), nvm, pyenv, uv, rust
#   git             - tmux (powerline fonts), vim (plugins), pyenv, nvm
#   build-essential - rust (cc is the default linker; rustup warns without it),
#                     pyenv (compiles Pythons), uv/pipx packages with C extensions;
#                     only the full profile needs a compiler, the minimal one
#                     (servers, containers) stays without the 40 packages it brings
# Like the Xcode Command Line Tools on macOS these are never removed.
PREREQUISITES=(curl git)
if [ "${DOTX_PROFILE:-full}" != "minimal" ]; then
  PREREQUISITES+=(build-essential)
fi

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
