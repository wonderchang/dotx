#!/usr/bin/env bash
# scripts/utils/symlink.sh
# Symlink management utilities
#
# Usage:
#   source scripts/utils/symlink.sh
#   create_symlink "$source" "$target"
#   remove_symlink "$target"

# ============================================================================
# Symlink Management
# ============================================================================

create_symlink() {
  local source="$1"
  local target="$2"

  # Backup existing file if it exists and is not a symlink
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    local backup="$target.backup.$(date +%Y%m%d_%H%M%S)"
    echo "  Backing up existing file: $target → $backup"
    mv "$target" "$backup"
  fi

  # Remove existing symlink if it exists
  if [ -L "$target" ]; then
    rm "$target"
  fi

  # Create symlink
  ln -s "$source" "$target"
  echo "  Created symlink: $target → $source"
}

remove_symlink() {
  local target="$1"

  # Remove symlink if it exists
  if [ -L "$target" ]; then
    rm -f "$target"
    echo "  Removed symlink: $target"
  elif [ -e "$target" ]; then
    echo "  Warning: $target exists but is not a symlink (skipping)"
  fi
}
