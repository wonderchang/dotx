#!/usr/bin/env bash
# common/claude/setup.sh
# Personal Claude Code instructions: ~/.claude/CLAUDE.md (the few global
# rules: language, safety) and ~/.claude/rules/ (thinking, output),
# which Claude Code loads in every project.
#
# Only these two entries are linked. ~/.claude itself is machine state
# (settings.json, history, sessions, plugins) and is never replaced; the
# `claude` binary is not installed here, like git only manages .gitconfig.
# Skills and output styles can be added later as further symlinks.
#
# A session started with CLAUDE_CONFIG_DIR=<dir> reads <dir>/CLAUDE.md and
# <dir>/rules instead (verified: it does not fall back to ~/.claude), so the
# same links go into every such directory that already exists. ~/.claude-work
# is the one dotx's own .bashrc uses (`claude-work` alias); more can be given
# in DOTX_CLAUDE_CONFIG_DIRS (colon-separated). None of them is created here
# except ~/.claude.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/utils/symlink.sh"

# ~/.claude always; the others only when they exist
claude_config_dirs() {
  local dir
  echo "$HOME/.claude"
  for dir in "$HOME/.claude-work" ${DOTX_CLAUDE_CONFIG_DIRS:+${DOTX_CLAUDE_CONFIG_DIRS//:/ }}; do
    [ "$dir" != "$HOME/.claude" ] && [ -d "$dir" ] && echo "$dir"
  done
  return 0
}

install_claude_setup() {
  local dir
  echo "=== Claude Code Setup ==="

  if [ ! -d "$HOME/.claude" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would create $HOME/.claude"
    else
      mkdir -p "$HOME/.claude"
    fi
  fi

  for dir in $(claude_config_dirs); do
    echo "Linking Claude Code instructions into $dir..."
    create_symlink "$SCRIPT_DIR/CLAUDE.md" "$dir/CLAUDE.md"
    create_symlink "$SCRIPT_DIR/rules" "$dir/rules"
  done
  echo "✓ Claude Code instructions linked"
  echo ""
}

uninstall_claude_setup() {
  local dir
  echo "=== Claude Code Uninstall ==="

  for dir in $(claude_config_dirs); do
    remove_symlink "$dir/rules"
    remove_symlink "$dir/CLAUDE.md"
  done
  # Only an empty ~/.claude goes (the one install created on a fresh machine)
  if [ "${DRY_RUN:-false}" != "true" ]; then
    rmdir "$HOME/.claude" 2>/dev/null || true
  fi
  echo ""
}

MODE="${1:-install}"

case "$MODE" in
  install)
    install_claude_setup
    ;;
  uninstall)
    uninstall_claude_setup
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
