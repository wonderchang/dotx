#!/usr/bin/env bash
# platform/ubuntu/gcloud.sh
# Google Cloud CLI (gcloud, gsutil, bq) from Google's APT repository
#
# Usage:
#   bash gcloud.sh install
#   bash gcloud.sh uninstall
#
# Notes:
#   - Installs the signing key to /usr/share/keyrings and the source list to
#     /etc/apt/sources.list.d, exactly as https://cloud.google.com/sdk/docs/install#deb
#     describes; both are removed again on uninstall.
#   - The APT build disables `gcloud components`; extra components are APT
#     packages too (e.g. google-cloud-cli-gke-gcloud-auth-plugin), and all
#     installed google-cloud-cli* packages are removed on uninstall.
#   - ~/.config/gcloud (credentials, configurations) is never touched.
#   - Needs sudo: the password is cached by request_sudo in setup.sh.

set -eu

PACKAGE="google-cloud-cli"
KEY_URL="https://packages.cloud.google.com/apt/doc/apt-key.gpg"
KEYRING="/usr/share/keyrings/cloud.google.gpg"
SOURCES_LIST="/etc/apt/sources.list.d/google-cloud-sdk.list"
SOURCES_LINE="deb [signed-by=$KEYRING] https://packages.cloud.google.com/apt cloud-sdk main"

apt_installed() {
  dpkg -l | grep -q "^ii  $1 "
}

install_gcloud() {
  echo "=== Google Cloud CLI ==="

  if apt_installed "$PACKAGE"; then
    echo "✓ $PACKAGE already installed"
    return 0
  fi

  if [ "${DRY_RUN:-false}" = "true" ]; then
    [ -f "$KEYRING" ] || echo "[DRY-RUN] Would add Google's APT signing key: $KEYRING"
    [ -f "$SOURCES_LIST" ] || echo "[DRY-RUN] Would add APT source: $SOURCES_LIST"
    echo "[DRY-RUN] Would run: sudo apt-get update"
    echo "[DRY-RUN] Would install $PACKAGE via APT"
    return 0
  fi

  # gnupg provides gpg for --dearmor; the other two are usually present already
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates gnupg

  if [ -f "$KEYRING" ]; then
    echo "✓ APT signing key already present: $KEYRING"
  else
    echo "Adding Google's APT signing key..."
    curl -fsSL "$KEY_URL" | sudo gpg --dearmor --yes -o "$KEYRING"
    echo "✓ APT signing key added: $KEYRING"
  fi

  if [ -f "$SOURCES_LIST" ] && grep -qxF "$SOURCES_LINE" "$SOURCES_LIST"; then
    echo "✓ APT source already present: $SOURCES_LIST"
  else
    echo "Adding APT source..."
    echo "$SOURCES_LINE" | sudo tee "$SOURCES_LIST" >/dev/null
    echo "✓ APT source added: $SOURCES_LIST"
  fi

  echo "Updating APT..."
  sudo DEBIAN_FRONTEND=noninteractive apt-get update

  echo "Installing $PACKAGE..."
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$PACKAGE"
  echo "✓ $PACKAGE installed (completion is wired up in .bashrc.ubuntu)"
}

uninstall_gcloud() {
  echo "=== Google Cloud CLI Uninstall ==="

  # Main package plus any add-on component packages from the same repo
  local packages
  packages=$(dpkg -l | awk '/^ii  google-cloud-cli/ {print $2}')

  if [ -n "$packages" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would uninstall via APT:" $packages
    else
      echo "Uninstalling" $packages "..."
      # shellcheck disable=SC2086  # word splitting of the package list is intended
      sudo apt-get remove -y $packages
      echo "✓ $PACKAGE uninstalled"
    fi
  else
    echo "✓ $PACKAGE not installed"
  fi

  local removed_repo=false
  local file
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

  if [ -d "$HOME/.config/gcloud" ]; then
    echo "  Note: ~/.config/gcloud (credentials, configurations) is kept"
  fi
}

# Execute based on mode
MODE="${1:-install}"

case "$MODE" in
  install)
    install_gcloud
    ;;
  uninstall)
    uninstall_gcloud
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
