#!/usr/bin/env bash
# common/claude/setup.sh
# Personal Claude Code instructions: ~/.claude/CLAUDE.md (the few global
# rules: language, safety) and ~/.claude/rules/ (thinking, output),
# which Claude Code loads in every project, plus the safety hook
# hooks/guard-destructive.sh, linked to ~/.claude/hooks/ and registered as a
# PreToolUse hook (matcher Bash) in ~/.claude/settings.json so that a
# destructive command becomes a permission prompt even in auto mode. The
# settings file is merged, not replaced: only the one entry whose command is
# our hook path is added or removed, everything else in it is kept, and the
# file is deleted on uninstall only if nothing else is left in it.
#
# Only these entries are linked. ~/.claude itself is machine state
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

# claude_settings_hook add|remove <settings.json> <hook command>
# Adds or removes the PreToolUse entry for <hook command>. Prints what it did.
claude_settings_hook() {
  python3 - "$1" "$2" "$3" <<'PY'
import json, os, sys
action, path, command = sys.argv[1:4]
settings = {}
if os.path.exists(path):
    with open(path) as f:
        settings = json.load(f)
pre = settings.setdefault("hooks", {}).setdefault("PreToolUse", [])
mine = [e for e in pre if any(h.get("command") == command for h in e.get("hooks", []))]
if action == "add":
    if mine:
        print("  ✓ Hook already registered in " + path)
        sys.exit(0)
    pre.append({"matcher": "Bash", "hooks": [{"type": "command", "command": command, "timeout": 10}]})
    print("  Registered PreToolUse hook in " + path)
else:
    if not mine:
        settings["hooks"].pop("PreToolUse") if not pre else None
        if not settings["hooks"]:
            settings.pop("hooks")
        sys.exit(0)
    pre[:] = [e for e in pre if e not in mine]
    if not pre:
        settings["hooks"].pop("PreToolUse")
    if not settings["hooks"]:
        settings.pop("hooks")
    print("  Removed PreToolUse hook from " + path)
    if not settings:
        os.remove(path)
        print("  Removed empty " + path)
        sys.exit(0)
with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PY
}

install_hook_in() {  # install_hook_in <config dir>
  local dir="$1" hook="$1/hooks/guard-destructive.sh"
  if [ "${DRY_RUN:-false}" = "true" ]; then
    [ -d "$dir/hooks" ] || echo "  [DRY-RUN] Would create $dir/hooks"
  else
    mkdir -p "$dir/hooks"
  fi
  create_symlink "$SCRIPT_DIR/hooks/guard-destructive.sh" "$hook"
  if ! command -v python3 >/dev/null 2>&1; then
    echo "  Warning: python3 not found, hook not registered in $dir/settings.json"
  elif [ "${DRY_RUN:-false}" = "true" ]; then
    echo "  [DRY-RUN] Would register $hook as a PreToolUse hook in $dir/settings.json"
  else
    claude_settings_hook add "$dir/settings.json" "$hook"
  fi
}

uninstall_hook_from() {  # uninstall_hook_from <config dir>
  local dir="$1" hook="$1/hooks/guard-destructive.sh"
  if ! command -v python3 >/dev/null 2>&1; then
    echo "  Warning: python3 not found, hook left registered in $dir/settings.json"
  elif [ "${DRY_RUN:-false}" = "true" ]; then
    [ -f "$dir/settings.json" ] && echo "  [DRY-RUN] Would remove the PreToolUse hook from $dir/settings.json"
  elif [ -f "$dir/settings.json" ]; then
    claude_settings_hook remove "$dir/settings.json" "$hook"
  fi
  remove_symlink "$hook"
  [ "${DRY_RUN:-false}" = "true" ] || rmdir "$dir/hooks" 2>/dev/null || true
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
    install_hook_in "$dir"
  done
  echo "✓ Claude Code instructions and safety hook linked"
  echo ""
}

uninstall_claude_setup() {
  local dir
  echo "=== Claude Code Uninstall ==="

  for dir in $(claude_config_dirs); do
    uninstall_hook_from "$dir"
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
