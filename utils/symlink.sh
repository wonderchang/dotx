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
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would backup existing file: $target → $backup"
    else
      echo "  Backing up existing file: $target → $backup"
      mv "$target" "$backup"
    fi
  fi

  # Remove existing symlink if it exists
  if [ -L "$target" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would remove existing symlink: $target"
    else
      rm "$target"
    fi
  fi

  # Create symlink
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "  [DRY-RUN] Would create symlink: $target → $source"
  else
    ln -s "$source" "$target"
    echo "  Created symlink: $target → $source"
  fi
}

remove_symlink() {
  local target="$1"

  # Remove symlink if it exists
  if [ -L "$target" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would remove symlink: $target"
    else
      rm -f "$target"
      echo "  Removed symlink: $target"
    fi
  elif [ -e "$target" ]; then
    echo "  Warning: $target exists but is not a symlink (skipping)"
  fi
}
