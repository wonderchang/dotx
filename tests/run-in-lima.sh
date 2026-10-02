#!/usr/bin/env bash
# tests/run-in-lima.sh
# Verify the Ubuntu side end to end in a Lima VM: install everything, check
# it, uninstall everything, check nothing is left and nothing that was there
# before is gone. Run from macOS with Lima installed (./bootstrap.sh lima).
#
# Usage:
#   tests/run-in-lima.sh            # reuse the dotx-ubuntu VM (create if missing)
#   tests/run-in-lima.sh --fresh    # delete and recreate the VM first (strict run)
#   tests/run-in-lima.sh --stop     # stop the VM when done
#
# The working tree (not just committed files) is synced into the VM, so this
# tests what you are about to commit. Exit code = number of failed checks.

set -eu

INSTANCE="${LIMA_INSTANCE:-dotx-ubuntu}"
TEMPLATE="${LIMA_TEMPLATE:-template:ubuntu-lts}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE=/tmp/dotx-test          # inside the VM
FRESH=false
STOP=false

for arg in "$@"; do
  case "$arg" in
    --fresh) FRESH=true ;;
    --stop)  STOP=true ;;
    *) echo "Unknown option: $arg"; sed -n '2,15p' "$0"; exit 2 ;;
  esac
done

case "$REPO_ROOT" in
  "$HOME"/*) ;;
  *) echo "✗ The repo must live under \$HOME ($HOME) to be visible inside the VM"; exit 2 ;;
esac
command -v limactl >/dev/null || { echo "✗ limactl not found; run ./bootstrap.sh lima first"; exit 2; }

vm() { limactl shell "$INSTANCE" -- bash -lc "$*"; }
step() { echo ""; echo "────────────────────────────────────────"; echo "  $*"; echo "────────────────────────────────────────"; }
failures=0
# run_checks <script>: runs a verify script in the VM, adds its failures
run_checks() {
  local rc=0
  vm "bash ~/dotx/tests/$1" || rc=$?
  failures=$((failures + rc))
}
# run_bootstrap <log> <args...>: runs bootstrap in the VM, shows the tail on failure
run_bootstrap() {
  local log="$1"; shift
  if vm "cd ~/dotx && ./bootstrap.sh $* > $STATE/$log 2>&1"; then
    echo "✓ ./bootstrap.sh $* finished (log: $STATE/$log in the VM)"
  else
    echo "✗ ./bootstrap.sh $* failed; last lines of $STATE/$log:"
    vm "tail -30 $STATE/$log"
    failures=$((failures + 1))
  fi
}

step "VM: $INSTANCE"
if [ "$FRESH" = "true" ]; then
  limactl delete -f "$INSTANCE" 2>/dev/null || true
fi
if ! limactl list -q 2>/dev/null | grep -qx "$INSTANCE"; then
  limactl start --name "$INSTANCE" --tty=false "$TEMPLATE"
elif [ "$(limactl list --format '{{.Status}}' "$INSTANCE")" != "Running" ]; then
  limactl start "$INSTANCE"
fi
vm 'lsb_release -ds; uname -m'

step "Snapshot the pre-dotx state"
if vm "test -d ~/.local/state/dotx || test -d ~/dotx" 2>/dev/null; then
  echo "⚠ The VM already has dotx state from an earlier run (~/dotx or ~/.local/state/dotx)."
  echo "  The clean check compares against a baseline that includes those installs, so"
  echo "  'no pre-existing package removed' is not meaningful here. Use --fresh for a strict run."
fi
vm "mkdir -p $STATE && dpkg-query -W -f='\${Package} \${db:Status-Status}\n' | awk '\$2 == \"installed\" {print \$1}' | LC_ALL=C sort > $STATE/pkgs-baseline.txt && cp ~/.bashrc $STATE/bashrc.orig 2>/dev/null || true; echo \"\$(wc -l < $STATE/pkgs-baseline.txt) packages installed\""

step "Sync working tree into the VM"
vm "rsync -a --delete --exclude .git '$REPO_ROOT/' ~/dotx/ && cd ~/dotx && ./bootstrap.sh --dry-run all > $STATE/dry-run.log 2>&1 && echo '✓ dry-run ok'"

step "Install everything"
run_bootstrap install-all.log all

step "Verify basic components"
run_checks verify-basic.sh
step "Verify optional components"
run_checks verify-optional.sh

step "Re-run install (must be a no-op)"
run_bootstrap install-again.log all
redo=$(vm "grep -cE '^(Installing|Cloning|Downloading)' $STATE/install-again.log" || true)
if [ "${redo:-0}" -eq 0 ]; then
  echo "✓ nothing re-installed"
else
  echo "✗ $redo install/clone/download line(s) on a re-run:"
  vm "grep -nE '^(Installing|Cloning|Downloading)' $STATE/install-again.log"
  failures=$((failures + 1))
fi

step "Uninstall everything"
run_bootstrap uninstall-all.log --uninstall all

step "Verify nothing is left"
run_checks verify-clean.sh

if [ "$STOP" = "true" ]; then
  step "Stop VM"
  limactl stop "$INSTANCE"
fi

echo ""
echo "════════════════════════════════════════"
if [ "$failures" -eq 0 ]; then
  echo "  ✓ All checks passed"
else
  echo "  ✗ $failures failure(s)"
fi
echo "════════════════════════════════════════"
exit "$failures"
