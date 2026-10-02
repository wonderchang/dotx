#!/usr/bin/env bash
# common/rust/setup.sh
# Platform-independent Rust setup (installation via rustup)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Remove auto-added cargo env line from a shell config file
# Args: $1 = file path (e.g., ~/.bashrc)
cleanup_cargo_env_line() {
  local file_path="$1"
  local file_name=$(basename "$file_path")

  # Resolve symlink to actual file
  if [ -L "$file_path" ]; then
    file_path=$(readlink -f "$file_path" 2>/dev/null || readlink "$file_path" 2>/dev/null || echo "$file_path")
  fi

  if [ -f "$file_path" ] && grep -q '^\. "\$HOME/\.cargo/env"' "$file_path"; then
    # cp -p first so the rewritten file keeps the original mode
    cp -p "$file_path" "$file_path.tmp"
    grep -v '^\. "\$HOME/\.cargo/env"' "$file_path" > "$file_path.tmp" || true
    mv -f "$file_path.tmp" "$file_path"
    echo "✓ Cleaned up auto-added line from $file_name"
  fi
}

install_rust_setup() {
  echo "=== Rust Setup ==="

  # Check if rustup is already installed
  if command -v rustup &> /dev/null; then
    echo "✓ Rust already installed: $(rustc --version)"
    return 0
  fi

  # Install Rust via rustup
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would download and install Rust from https://sh.rustup.rs"
    echo "[DRY-RUN] Would remove auto-added line from shell configs"
  else
    echo "Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    echo "✓ Rust installed"

    # Remove the line that rustup installer automatically adds to shell configs
    # We manage PATH ourselves in .bashrc
    cleanup_cargo_env_line "$HOME/.bashrc"
    cleanup_cargo_env_line "$HOME/.bash_profile"
    cleanup_cargo_env_line "$HOME/.profile"
  fi

  echo ""
  echo "Note: Rust is installed to ~/.cargo"
  echo "      ~/.cargo/bin is added to PATH via .bashrc"
  echo ""
}

uninstall_rust_setup() {
  echo "=== Rust Uninstall ==="

  # Check if rustup exists (don't rely on PATH)
  if [ ! -f "$HOME/.cargo/bin/rustup" ]; then
    echo "✓ Rust not installed"
    return 0
  fi

  # Uninstall via rustup
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "  [DRY-RUN] Would run: rustup self uninstall -y"
  else
    echo "Uninstalling Rust via rustup..."
    "$HOME/.cargo/bin/rustup" self uninstall -y
    echo "✓ Rust uninstalled"
  fi
  echo ""
}

# Execute based on mode
MODE="${1:-install}"

case "$MODE" in
  install)
    install_rust_setup
    ;;
  uninstall)
    uninstall_rust_setup
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
