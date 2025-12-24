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

  # Check if symlink already exists
  if [ -L "$target" ]; then
    local current_source=$(readlink "$target")

    # Check if it points to the correct source
    if [ "$current_source" = "$source" ]; then
      echo "  ✓ Symlink already correct: $target → $source"
      return 0  # Skip unnecessary work - truly idempotent!
    else
      # Symlink exists but points to wrong source - needs update
      if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "  [DRY-RUN] Would update symlink: $target"
        echo "      Current: $target → $current_source"
        echo "      New:     $target → $source"
      else
        echo "  Updating symlink: $target"
        echo "      Old: $current_source → New: $source"
        rm "$target"
      fi
    fi
  # Backup existing regular file (not a symlink)
  elif [ -e "$target" ]; then
    local backup="$target.backup.$(date +%Y%m%d_%H%M%S)"
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would backup existing file: $target → $backup"
    else
      echo "  Backing up existing file: $target → $backup"
      mv "$target" "$backup"
    fi
  fi

  # Create symlink (only if we didn't return early)
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
