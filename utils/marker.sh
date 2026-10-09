#!/usr/bin/env bash
# utils/marker.sh
# "dotx installed this" markers for tools that live in the home directory
# (nvm, pyenv, uv, rust). Install writes the marker only after dotx itself
# installed the tool; uninstall removes the tool only when the marker is
# there, so a toolchain that was on the machine before dotx (with its Node
# and Python versions, Rust toolchains) is never deleted by `--uninstall`.
# Machines set up before the markers existed have none: seed one by hand with
# `touch ~/.local/state/dotx/<name>-installed` to hand that tool to dotx.
#
# Usage:
#   source utils/marker.sh
#   mark_installed nvm
#   if is_marked_installed nvm; then ...; fi
#   unmark_installed nvm

DOTX_STATE_DIR="$HOME/.local/state/dotx"

marker_path() {
  echo "$DOTX_STATE_DIR/$1-installed"
}

mark_installed() {
  mkdir -p "$DOTX_STATE_DIR"
  touch "$(marker_path "$1")"
}

is_marked_installed() {
  [ -f "$(marker_path "$1")" ]
}

# Remove the marker, and the state directories once nothing else is in them
unmark_installed() {
  rm -f "$(marker_path "$1")"
  rmdir "$DOTX_STATE_DIR" "$(dirname "$DOTX_STATE_DIR")" 2>/dev/null || true
}
