#!/usr/bin/env bash
# common/bash/setup.sh
# Platform-independent bash setup (shared configuration)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities
source "$PROJECT_ROOT/utils/symlink.sh"

BASH_GIT_PROMPT_VERSION="2.7.1"
BASH_GIT_PROMPT_DIR="$HOME/.bash-git-prompt"

install_bash_setup() {
  echo "=== Bash Setup ==="

  # 1. Create symlinks for bash configs
  echo "Linking bash configuration..."
  create_symlink "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
  create_symlink "$SCRIPT_DIR/.bash_profile" "$HOME/.bash_profile"
  echo "✓ Bash configuration linked"
  echo ""

  # 2. Install bash-git-prompt
  echo "=== Installing bash-git-prompt ==="
  if [ -d "$BASH_GIT_PROMPT_DIR" ]; then
    echo "✓ bash-git-prompt already installed"
  else
    echo "Installing bash-git-prompt ${BASH_GIT_PROMPT_VERSION}..."
    local tmp_src="bash-git-prompt-${BASH_GIT_PROMPT_VERSION}"
    local tmp_tarball="${tmp_src}.tar.gz"

    curl -L -o "$tmp_tarball" \
      "https://github.com/magicmonty/bash-git-prompt/archive/${BASH_GIT_PROMPT_VERSION}.tar.gz"
    tar zxf "$tmp_tarball"
    mkdir -p "$BASH_GIT_PROMPT_DIR"
    rsync -a "${tmp_src}/" "$BASH_GIT_PROMPT_DIR/"
    rm -rf "$tmp_src" "$tmp_tarball"

    echo "✓ bash-git-prompt installed"
  fi

  # 3. Install custom theme if it exists
  if [ -f "$SCRIPT_DIR/WonderChang.bgptheme" ]; then
    echo "Installing WonderChang theme..."
    create_symlink "$SCRIPT_DIR/WonderChang.bgptheme" "$BASH_GIT_PROMPT_DIR/themes/WonderChang.bgptheme"
    echo "✓ WonderChang theme installed"
  fi

  echo ""
}

uninstall_bash_setup() {
  echo "=== Bash Uninstall ==="

  # 1. Remove symlinks
  remove_symlink "$HOME/.bashrc"
  remove_symlink "$HOME/.bash_profile"

  # 2. Remove bash-git-prompt theme symlink
  if [ -L "$BASH_GIT_PROMPT_DIR/themes/WonderChang.bgptheme" ]; then
    remove_symlink "$BASH_GIT_PROMPT_DIR/themes/WonderChang.bgptheme"
  fi

  # 3. Remove bash-git-prompt
  if [ -d "$BASH_GIT_PROMPT_DIR" ]; then
    rm -rf "$BASH_GIT_PROMPT_DIR"
    echo "  Removed bash-git-prompt"
  fi

  echo ""
}

# Execute based on mode
MODE="${1:-install}"

case "$MODE" in
  install)
    install_bash_setup
    ;;
  uninstall)
    uninstall_bash_setup
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
