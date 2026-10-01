#!/usr/bin/env bash
# utils/sudo.sh
# Ask for the administrator password once, then keep sudo's credential cache
# alive for the rest of the run so later steps (Homebrew installer, /etc/shells,
# dscl/chsh, apt-get) never prompt again.
#
# Usage:
#   source utils/sudo.sh
#   request_sudo "reason shown to the user"
#
# The password itself is never stored; only sudo's own timestamp is refreshed.
#
# Anything run later must not reset that timestamp: `brew` does so on every
# invocation unless HOMEBREW_NO_SUDO=1 is exported (platform/macos/setup.sh).

# ============================================================================
# Sudo Session
# ============================================================================

SUDO_KEEPALIVE_PID=""

stop_sudo_keepalive() {
  if [ -n "$SUDO_KEEPALIVE_PID" ]; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    SUDO_KEEPALIVE_PID=""
  fi
}

request_sudo() {
  local reason="${1:-administrator rights are needed}"

  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would ask for your password once ($reason)"
    echo ""
    return 0
  fi

  # Already cached (e.g. a sudo command ran a moment ago)? Then don't ask.
  if sudo -n true 2>/dev/null; then
    echo "✓ Administrator rights already cached"
  else
    echo "=== Administrator Password ==="
    echo "Some steps need administrator rights: $reason"
    echo "Enter your password once now; it will be reused for the rest of this run."
    sudo -v
    echo "✓ Administrator rights granted"
  fi
  echo ""

  # Refresh sudo's timestamp every minute until this script exits
  # (default timeout is 5 minutes, slow steps like brew install can exceed it).
  if [ -z "$SUDO_KEEPALIVE_PID" ]; then
    (
      while kill -0 "$$" 2>/dev/null; do
        sudo -n true 2>/dev/null || true
        sleep 60
      done
    ) &
    SUDO_KEEPALIVE_PID=$!
    disown "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    trap stop_sudo_keepalive EXIT
  fi
}
