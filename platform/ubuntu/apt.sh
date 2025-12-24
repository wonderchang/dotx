#!/usr/bin/env bash
# platform/ubuntu/apt.sh
# Update APT package manager on Ubuntu

set -eu

update_apt() {
  echo "=== Updating APT ==="

  sudo apt-get update
  echo "✓ APT updated"
  echo ""
}

# Execute
update_apt
