#!/usr/bin/env bash
# platform/ubuntu/aws.sh
# AWS CLI v2 from the official installer, into the user's home (no sudo)
#
# Usage:
#   bash aws.sh install
#   bash aws.sh uninstall
#
# Notes:
#   - Ubuntu's `awscli` APT package is v1 on 22.04 and lags on later releases,
#     so this follows https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
#     but installs under ~/.local/aws-cli with the `aws`/`aws_completer`
#     symlinks in ~/.local/bin (already on PATH via .bashrc, shared with
#     pipx and uv). Only `unzip` needs APT (sudo cached by setup.sh).
#   - ~/.aws (credentials, config) is never touched.
#   - Completion is wired up in common/bash/.bashrc via aws_completer.

set -eu

INSTALL_DIR="$HOME/.local/aws-cli"
BIN_DIR="$HOME/.local/bin"

installer_url() {
  case "$(uname -m)" in
    x86_64)        echo "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" ;;
    aarch64|arm64) echo "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" ;;
    *)             echo "" ;;
  esac
}

install_aws() {
  echo "=== AWS CLI ==="

  if [ -x "$BIN_DIR/aws" ]; then
    echo "✓ aws already installed: $("$BIN_DIR/aws" --version 2>&1 | cut -d' ' -f1)"
    return 0
  fi

  local url
  url=$(installer_url)
  if [ -z "$url" ]; then
    echo "  ✗ Unsupported architecture for the AWS CLI installer: $(uname -m)"
    return 1
  fi

  if [ "${DRY_RUN:-false}" = "true" ]; then
    dpkg -l | grep -q "^ii  unzip " || echo "[DRY-RUN] Would install unzip via APT"
    echo "[DRY-RUN] Would download $url"
    echo "[DRY-RUN] Would install AWS CLI to $INSTALL_DIR with symlinks in $BIN_DIR"
    return 0
  fi

  if ! dpkg -l | grep -q "^ii  unzip "; then
    echo "Installing unzip..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unzip
  fi

  local tmp
  tmp=$(mktemp -d)
  echo "Downloading AWS CLI..."
  curl -fSL --progress-bar -o "$tmp/awscliv2.zip" "$url"
  unzip -q "$tmp/awscliv2.zip" -d "$tmp"
  echo "Installing AWS CLI to $INSTALL_DIR..."
  mkdir -p "$BIN_DIR"
  "$tmp/aws/install" --install-dir "$INSTALL_DIR" --bin-dir "$BIN_DIR" --update
  rm -rf "$tmp"
  echo "✓ aws installed: $("$BIN_DIR/aws" --version 2>&1 | cut -d' ' -f1)"
}

uninstall_aws() {
  echo "=== AWS CLI Uninstall ==="

  if [ ! -d "$INSTALL_DIR" ] && [ ! -L "$BIN_DIR/aws" ] && [ ! -L "$BIN_DIR/aws_completer" ]; then
    echo "✓ aws not installed"
    return 0
  fi

  local path
  for path in "$BIN_DIR/aws" "$BIN_DIR/aws_completer" "$INSTALL_DIR"; do
    if [ -e "$path" ] || [ -L "$path" ]; then
      if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "  [DRY-RUN] Would remove $path"
      else
        rm -rf "$path"
        echo "  Removed $path"
      fi
    fi
  done

  if [ -d "$HOME/.aws" ]; then
    echo "  Note: ~/.aws (credentials, config) is kept"
  fi
}

# Execute based on mode
MODE="${1:-install}"

case "$MODE" in
  install)
    install_aws
    ;;
  uninstall)
    uninstall_aws
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
