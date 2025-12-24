#!/usr/bin/env bash
# platform/ubuntu/apt.sh
# Update APT package manager on Ubuntu

set -eu

update_apt() {
  echo "=== Updating APT ==="

  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would run: sudo apt-get update"
  else
    sudo apt-get update
    echo "✓ APT updated"
  fi
  echo ""
}

# Execute
update_apt
