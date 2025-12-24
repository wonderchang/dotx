#!/usr/bin/env bash
# utils/shell.sh
# Shell detection and switching utilities

# ============================================================================
# Shell Detection and Switching
# ============================================================================

get_current_shell() {
  # Get user's default shell from /etc/passwd
  dscl . -read ~/ UserShell | awk '{print $2}'
}

switch_to_bash() {
  local current_shell=$(get_current_shell)
  local bash_path

  # On macOS, use Homebrew bash (required to be installed first)
  # This gives us modern bash (5.x) instead of old system bash (3.2)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v /opt/homebrew/bin/bash &>/dev/null; then
      bash_path="/opt/homebrew/bin/bash"
    elif command -v /usr/local/bin/bash &>/dev/null; then
      bash_path="/usr/local/bin/bash"
    else
      echo "  ✗ Error: Homebrew bash not found"
      echo "  Please install bash via Homebrew first: brew install bash"
      return 1
    fi
  # On Linux, use system bash
  elif command -v /bin/bash &>/dev/null; then
    bash_path="/bin/bash"
  else
    echo "  ✗ Error: bash not found on system"
    return 1
  fi

  # Check if already using bash
  if [ "$current_shell" = "$bash_path" ]; then
    echo "  ✓ Default shell is already bash: $bash_path"
    return 0
  fi

  # Need to switch to bash
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "  [DRY-RUN] Would switch default shell to bash"
    echo "      Current: $current_shell"
    echo "      New:     $bash_path"
    echo "      Command: chsh -s $bash_path"
  else
    echo "  Switching default shell to bash..."
    echo "      Current: $current_shell"
    echo "      New:     $bash_path"
    echo ""
    echo "  You may be prompted for your password."

    # Ensure bash is in /etc/shells
    if ! grep -q "^${bash_path}$" /etc/shells; then
      echo "  Adding $bash_path to /etc/shells..."
      echo "$bash_path" | sudo tee -a /etc/shells >/dev/null
    fi

    # Change shell
    chsh -s "$bash_path"

    if [ $? -eq 0 ]; then
      echo ""
      echo "  ✓ Default shell changed to bash"
      echo "  ⚠ Note: You need to restart your terminal or logout/login for changes to take effect"
    else
      echo ""
      echo "  ✗ Failed to change default shell"
      return 1
    fi
  fi

  return 0
}

restore_shell() {
  local target_shell="$1"

  if [ -z "$target_shell" ]; then
    echo "  ✗ Error: No shell specified to restore"
    return 1
  fi

  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "  [DRY-RUN] Would restore default shell to: $target_shell"
  else
    echo "  Restoring default shell to: $target_shell"
    chsh -s "$target_shell"

    if [ $? -eq 0 ]; then
      echo "  ✓ Default shell restored"
      echo "  ⚠ Note: You need to restart your terminal or logout/login for changes to take effect"
    else
      echo "  ✗ Failed to restore default shell"
      return 1
    fi
  fi

  return 0
}
