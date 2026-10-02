#!/usr/bin/env bash
# platform/ubuntu/docker.sh
# Docker Engine from Docker's own APT repository
#
# Usage:
#   bash docker.sh install
#   bash docker.sh uninstall
#
# Notes:
#   - Follows https://docs.docker.com/engine/install/ubuntu/: signing key in
#     /etc/apt/keyrings/docker.asc, source list in
#     /etc/apt/sources.list.d/docker.list, packages docker-ce docker-ce-cli
#     containerd.io docker-buildx-plugin docker-compose-plugin (all recorded
#     in the dotx APT manifest, so uninstall removes exactly them).
#   - If Docker has no repository for this Ubuntu release yet, the previous
#     LTS codename is used with a warning.
#   - The user is added to the `docker` group (membership equals root; it is
#     what Docker's post-install docs do) and removed again on uninstall if
#     dotx added it. A new login is needed for the group to take effect.
#   - /var/lib/docker and /var/lib/containerd (images, volumes) are kept on
#     uninstall; the uninstall prints how to remove them.
#   - Needs sudo: the password is cached by request_sudo in setup.sh.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/apt-common.sh"

KEY_URL="https://download.docker.com/linux/ubuntu/gpg"
KEYRING="/etc/apt/keyrings/docker.asc"
SOURCES_LIST="/etc/apt/sources.list.d/docker.list"
REPO_URL="https://download.docker.com/linux/ubuntu"
PACKAGES=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
FALLBACK_CODENAME="noble"
GROUP_MARKER="$HOME/.local/state/dotx/docker-group-added"

# Ubuntu codename Docker publishes packages for
repo_codename() {
  local codename
  codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
  if curl -fsSI "$REPO_URL/dists/$codename/Release" >/dev/null 2>&1; then
    echo "$codename"
  else
    echo "⚠ Docker has no APT repository for '$codename' yet; using '$FALLBACK_CODENAME'" >&2
    echo "$FALLBACK_CODENAME"
  fi
}

sources_line() {
  echo "deb [arch=$(dpkg --print-architecture) signed-by=$KEYRING] $REPO_URL $1 stable"
}

in_docker_group() {
  id -nG "$USER" | tr ' ' '\n' | grep -qx docker
}

install_docker() {
  echo "=== Docker Engine ==="

  if apt_installed docker-ce; then
    echo "✓ docker-ce already installed: $(docker --version 2>/dev/null)"
  elif [ "${DRY_RUN:-false}" = "true" ]; then
    [ -f "$KEYRING" ] || echo "[DRY-RUN] Would add Docker's APT signing key: $KEYRING"
    [ -f "$SOURCES_LIST" ] || echo "[DRY-RUN] Would add APT source: $SOURCES_LIST"
    echo "[DRY-RUN] Would run: sudo apt-get update"
    echo "[DRY-RUN] Would install via APT (recorded for docker): ${PACKAGES[*]}"
  else
    if [ -f "$KEYRING" ]; then
      echo "✓ APT signing key already present: $KEYRING"
    else
      echo "Adding Docker's APT signing key..."
      sudo install -m 0755 -d "$(dirname "$KEYRING")"
      curl -fsSL "$KEY_URL" | sudo tee "$KEYRING" >/dev/null
      sudo chmod a+r "$KEYRING"
      echo "✓ APT signing key added: $KEYRING"
    fi

    local codename line
    codename=$(repo_codename)
    line=$(sources_line "$codename")
    if [ -f "$SOURCES_LIST" ] && grep -qxF "$line" "$SOURCES_LIST"; then
      echo "✓ APT source already present: $SOURCES_LIST"
    else
      echo "Adding APT source ($codename)..."
      echo "$line" | sudo tee "$SOURCES_LIST" >/dev/null
      echo "✓ APT source added: $SOURCES_LIST"
    fi

    echo "Updating APT..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
    install_apt_packages_for docker "${PACKAGES[@]}"
    echo "✓ Docker Engine installed: $(docker --version)"
  fi

  echo ""
  echo "=== Docker Group ==="
  if in_docker_group; then
    echo "✓ $USER is already in the docker group"
  elif [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would add $USER to the docker group"
  else
    sudo usermod -aG docker "$USER"
    mkdir -p "$(dirname "$GROUP_MARKER")"
    touch "$GROUP_MARKER"
    echo "✓ $USER added to the docker group"
    echo "  ⚠ Log out and back in (or run \`newgrp docker\`) before using docker without sudo"
  fi
  echo ""
}

uninstall_docker() {
  echo "=== Docker Engine Uninstall ==="

  if in_docker_group && [ -f "$GROUP_MARKER" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would remove $USER from the docker group"
    else
      sudo gpasswd -d "$USER" docker >/dev/null
      rm -f "$GROUP_MARKER"
      echo "  Removed $USER from the docker group"
    fi
  elif in_docker_group; then
    echo "  Note: $USER was in the docker group before dotx; kept"
  fi

  uninstall_apt_packages_for docker

  local removed_repo=false file
  for file in "$SOURCES_LIST" "$KEYRING"; do
    if [ -f "$file" ]; then
      if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "  [DRY-RUN] Would remove $file"
      else
        sudo rm -f "$file"
        echo "  Removed $file"
        removed_repo=true
      fi
    fi
  done
  if [ "$removed_repo" = "true" ]; then
    echo "Updating APT..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
  fi

  if [ -d /var/lib/docker ] || [ -d /var/lib/containerd ]; then
    echo "  Note: images, containers and volumes are kept; remove with:"
    echo "    sudo rm -rf /var/lib/docker /var/lib/containerd"
  fi
  echo ""
}

MODE="${1:-install}"
case "$MODE" in
  install)   install_docker ;;
  uninstall) uninstall_docker ;;
  *) echo "Unknown mode: $MODE"; exit 1 ;;
esac
