#!/usr/bin/env bash
# platform/macos/iterm2.sh
# Configure iTerm2: Powerline font for the default profile (for tmux theme)
# dotx Dynamic Profiles (e.g. Smyck profile) and color presets (*.itermcolors)
#
# Usage:
#   bash iterm2.sh install
#   bash iterm2.sh uninstall
#
# Notes:
#   - iTerm2 keeps profiles in memory and overwrites preferences on save,
#     so changes are only applied while iTerm2 is NOT running.
#   - Preferences are exported/imported via `defaults` so cfprefsd stays in sync.
#   - Dynamic Profiles are symlinked and hot-reloaded, so they are linked
#     even while iTerm2 is running.
#   - Color presets are imported with `open` (launches iTerm2 if needed) and
#     are kept on uninstall (remove via Profiles → Colors → Color Presets).

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source utilities
source "$PROJECT_ROOT/utils/symlink.sh"

ITERM2_DOMAIN="com.googlecode.iterm2"
ITERM2_APP="/Applications/iTerm.app"
POWERLINE_FONT="SourceCodeProForPowerline-Regular"
POWERLINE_FONT_FILE="$HOME/Library/Fonts/Source Code Pro for Powerline.otf"
DEFAULT_FONT_SIZE="12"
BACKUP_FILE="$HOME/.config/dotx/iterm2-font.backup"
PLISTBUDDY="/usr/libexec/PlistBuddy"
PROFILES_SRC_DIR="$SCRIPT_DIR/iterm2"
DYNAMIC_PROFILES_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"

# ============================================================================
# Helper Functions
# ============================================================================

iterm2_installed() {
  [ -d "$ITERM2_APP" ]
}

iterm2_running() {
  pgrep -x iTerm2 &>/dev/null
}

color_preset_imported() {
  local name="$1"
  defaults read "$ITERM2_DOMAIN" "Custom Color Presets" 2>/dev/null \
    | grep -q -E "^    \"?${name}\"? = "
}

# Print index of the default profile in "New Bookmarks" (empty if not found)
default_profile_index() {
  local plist="$1"
  local default_guid
  default_guid=$(defaults read "$ITERM2_DOMAIN" "Default Bookmark Guid" 2>/dev/null) || return 0

  local i=0
  local guid
  while guid=$("$PLISTBUDDY" -c "Print :New\ Bookmarks:$i:Guid" "$plist" 2>/dev/null); do
    if [ "$guid" = "$default_guid" ]; then
      echo "$i"
      return 0
    fi
    i=$((i + 1))
  done
}

# Print name of the dotx dynamic profile set as default (empty if none)
default_dynamic_profile() {
  local default_guid
  default_guid=$(defaults read "$ITERM2_DOMAIN" "Default Bookmark Guid" 2>/dev/null) || return 0

  local profile
  for profile in "$PROFILES_SRC_DIR"/*.json; do
    if grep -q "\"Guid\": \"$default_guid\"" "$profile"; then
      basename "$profile" .json
      return 0
    fi
  done
}

print_manual_instructions() {
  echo "  To set it manually: iTerm2 → Settings → Profiles → Text → Font"
  echo "  → choose 'Source Code Pro for Powerline'"
  echo "  Or quit iTerm2 and re-run from Terminal.app: ./bootstrap.sh tmux"
}

# Set Normal Font of the default profile
#   $1 = font spec, e.g. "Monaco 12"; a bare name keeps the current size
#   $2 = "backup" (optional) to save the previous font before changing
set_default_profile_font() {
  local new_font="$1"
  local do_backup="${2:-}"

  local tmp_dir tmp_plist
  tmp_dir=$(mktemp -d)
  tmp_plist="$tmp_dir/iterm2.plist"
  defaults export "$ITERM2_DOMAIN" "$tmp_plist"

  local idx
  idx=$(default_profile_index "$tmp_plist")
  if [ -z "$idx" ]; then
    local dynamic
    dynamic=$(default_dynamic_profile)
    if [ -n "$dynamic" ]; then
      echo "✓ iTerm2 default profile is dotx dynamic profile '$dynamic' (font set in its JSON)"
    else
      echo "⚠ iTerm2 default profile not found (open iTerm2 once to create it)"
    fi
    rm -rf "$tmp_dir"
    return 0
  fi

  local key=":New\ Bookmarks:$idx:Normal\ Font"
  local current_font
  current_font=$("$PLISTBUDDY" -c "Print $key" "$tmp_plist" 2>/dev/null || echo "")

  case "${new_font##* }" in
    ''|*[!0-9.]*)
      local size="${current_font##* }"
      case "$size" in
        ''|*[!0-9.]*) size="$DEFAULT_FONT_SIZE" ;;
      esac
      new_font="$new_font $size"
      ;;
  esac

  if [ "$current_font" = "$new_font" ]; then
    echo "✓ iTerm2 font already set: $new_font"
    rm -rf "$tmp_dir"
    return 0
  fi

  # On install, respect a Powerline/Nerd font the user already picked
  if [ "$do_backup" = "backup" ]; then
    case "$current_font" in
      *Powerline*|*NerdFont*|*Nerd\ Font*)
        echo "✓ iTerm2 already uses a Powerline font: $current_font"
        rm -rf "$tmp_dir"
        return 0
        ;;
    esac
  fi

  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would change iTerm2 font: '${current_font:-<unset>}' → '$new_font'"
    rm -rf "$tmp_dir"
    return 0
  fi

  if [ "$do_backup" = "backup" ] && [ -n "$current_font" ]; then
    mkdir -p "$(dirname "$BACKUP_FILE")"
    echo "$current_font" > "$BACKUP_FILE"
    echo "  Saved previous font to $BACKUP_FILE"
  fi

  "$PLISTBUDDY" -c "Set $key $new_font" "$tmp_plist" 2>/dev/null \
    || "$PLISTBUDDY" -c "Add $key string $new_font" "$tmp_plist"
  defaults import "$ITERM2_DOMAIN" "$tmp_plist"
  rm -rf "$tmp_dir"
  echo "✓ iTerm2 font changed: '${current_font:-<unset>}' → '$new_font'"

  local use_non_ascii
  use_non_ascii=$(defaults read "$ITERM2_DOMAIN" "New Bookmarks" 2>/dev/null \
    | grep -c '"Use Non-ASCII Font" = 1' || true)
  if [ "$use_non_ascii" != "0" ]; then
    echo "⚠ A profile uses a separate non-ASCII font; Powerline glyphs render"
    echo "  with that font, so set it to a Powerline font too (Profiles → Text)"
  fi
}

# ============================================================================
# Mode: Install
# ============================================================================

install_dynamic_profiles() {
  echo "=== iTerm2 Dynamic Profiles ==="

  if ! iterm2_installed; then
    echo "✓ iTerm2 not installed, skipping"
    echo ""
    return 0
  fi

  if [ "${DRY_RUN:-false}" = "true" ]; then
    [ -d "$DYNAMIC_PROFILES_DIR" ] || echo "[DRY-RUN] Would create $DYNAMIC_PROFILES_DIR"
  else
    mkdir -p "$DYNAMIC_PROFILES_DIR"
  fi

  local profile
  for profile in "$PROFILES_SRC_DIR"/*.json; do
    create_symlink "$profile" "$DYNAMIC_PROFILES_DIR/dotx-$(basename "$profile")"
  done
  echo "✓ Dynamic profiles linked (iTerm2 → Settings → Profiles)"
  echo ""
}

install_iterm2_font() {
  echo "=== iTerm2 Powerline Font ==="

  if ! iterm2_installed; then
    echo "✓ iTerm2 not installed, skipping"
    echo ""
    return 0
  fi

  # Dynamic profiles carry their own font, so there is nothing to change
  local dynamic
  dynamic=$(default_dynamic_profile)
  if [ -n "$dynamic" ]; then
    echo "✓ iTerm2 default profile is dotx dynamic profile '$dynamic' (font set in its JSON)"
    echo ""
    return 0
  fi

  if iterm2_running; then
    echo "⚠ iTerm2 is running; skipping font change (iTerm2 would overwrite it)"
    print_manual_instructions
    echo ""
    return 0
  fi

  if [ ! -f "$POWERLINE_FONT_FILE" ] && [ "${DRY_RUN:-false}" != "true" ]; then
    echo "⚠ Powerline font not found: $POWERLINE_FONT_FILE"
    echo "  Run './bootstrap.sh tmux' to install powerline fonts first"
    echo ""
    return 0
  fi

  set_default_profile_font "$POWERLINE_FONT" backup
  echo ""
}

import_color_presets() {
  echo "=== iTerm2 Color Presets ==="

  if ! iterm2_installed; then
    echo "✓ iTerm2 not installed, skipping"
    echo ""
    return 0
  fi

  local preset name
  for preset in "$PROFILES_SRC_DIR"/*.itermcolors; do
    name=$(basename "$preset" .itermcolors)
    if color_preset_imported "$name"; then
      echo "  ✓ Color preset already imported: $name"
    elif [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would import color preset: $name"
    else
      open -a iTerm "$preset"
      echo "  Imported color preset: $name"
    fi
  done
  echo "✓ Color presets available (Profiles → Colors → Color Presets)"
  echo ""
}

# ============================================================================
# Mode: Uninstall
# ============================================================================

uninstall_dynamic_profiles() {
  echo "=== iTerm2 Dynamic Profiles Uninstall ==="

  local profile
  for profile in "$PROFILES_SRC_DIR"/*.json; do
    remove_symlink "$DYNAMIC_PROFILES_DIR/dotx-$(basename "$profile")"
  done
  echo ""
}

uninstall_iterm2_font() {
  echo "=== iTerm2 Font Restore ==="

  if ! iterm2_installed || [ ! -f "$BACKUP_FILE" ]; then
    echo "✓ No iTerm2 font backup to restore"
    echo ""
    return 0
  fi

  if iterm2_running; then
    echo "⚠ iTerm2 is running; skipping font restore (iTerm2 would overwrite it)"
    echo "  Quit iTerm2 and re-run from Terminal.app: ./bootstrap.sh --uninstall tmux"
    echo ""
    return 0
  fi

  set_default_profile_font "$(cat "$BACKUP_FILE")"
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would remove $BACKUP_FILE"
  else
    rm -f "$BACKUP_FILE"
  fi
  echo ""
}

# ============================================================================
# Main
# ============================================================================

MODE="${1:-install}"

case "$MODE" in
  install)
    install_iterm2_font
    install_dynamic_profiles
    import_color_presets
    ;;
  uninstall)
    uninstall_dynamic_profiles
    uninstall_iterm2_font
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac
