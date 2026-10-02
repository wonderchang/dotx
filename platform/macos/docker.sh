#!/usr/bin/env bash
# platform/macos/docker.sh
# Docker on macOS without Docker Desktop: the docker CLI (plus compose and
# buildx plugins and the keychain credential helper) from Homebrew, and
# colima running a rootful dockerd in a Lima VM.
#
# Usage:
#   bash docker.sh install
#   bash docker.sh uninstall
#
# Notes:
#   - Why not Docker Desktop: its cask needs sudo in the postflight (clashes
#     with HOMEBREW_NO_SUDO), the first launch must be clicked through in the
#     GUI, and it is paid for larger companies. Why colima over Lima's own
#     docker template: colima runs rootful docker (same behaviour as Docker
#     Desktop; Lima's template is rootless), sets the docker context itself,
#     and `brew services` can start it at login. colima depends on the lima
#     formula, so it coexists with the lima component.
#   - The colima profile is only created when none exists; an existing
#     profile (with its images and containers) is left exactly as it is, and
#     uninstall only deletes the profile this script created.
#   - Plugins: Homebrew puts compose/buildx in $(brew --prefix)/lib/docker/
#     cli-plugins; docker finds them through "cliPluginsExtraDirs" in
#     ~/.docker/config.json. Credentials: "credsStore": "osxkeychain".
#   - Tools that ignore `docker context` need
#     DOCKER_HOST=unix://~/.colima/default/docker.sock (see .bashrc.macos).

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/brew-common.sh"

BREW_PREFIX="$(brew --prefix)"
PLUGIN_DIR="$BREW_PREFIX/lib/docker/cli-plugins"
DOCKER_CONFIG_FILE="$HOME/.docker/config.json"
COLIMA_PROFILE="default"
# Resources for a profile created by dotx (an existing profile is not changed)
COLIMA_CPU="${DOTX_COLIMA_CPU:-4}"
COLIMA_MEMORY="${DOTX_COLIMA_MEMORY:-8}"
COLIMA_DISK="${DOTX_COLIMA_DISK:-100}"
STATE_DIR="$HOME/.local/state/dotx"
PROFILE_MARKER="$STATE_DIR/colima-profile-created"
CONFIG_MARKER="$STATE_DIR/docker-config-created"

colima_profile_exists() {
  colima list 2>/dev/null | awk 'NR > 1 {print $1}' | grep -qx "$COLIMA_PROFILE"
}

colima_running() {
  colima status --profile "$COLIMA_PROFILE" &>/dev/null
}

# Make sure ~/.docker/config.json points docker at Homebrew's plugin dir and
# the keychain credential helper. Creates the file when missing; merges the
# two keys into an existing file (python3 ships with the Xcode CLT that
# Homebrew already requires); never touches existing "auths".
configure_docker_cli() {
  if [ ! -f "$DOCKER_CONFIG_FILE" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would create $DOCKER_CONFIG_FILE (cliPluginsExtraDirs, credsStore)"
      return 0
    fi
    mkdir -p "$(dirname "$DOCKER_CONFIG_FILE")"
    printf '{\n\t"cliPluginsExtraDirs": [\n\t\t"%s"\n\t],\n\t"credsStore": "osxkeychain"\n}\n' "$PLUGIN_DIR" > "$DOCKER_CONFIG_FILE"
    mkdir -p "$STATE_DIR"
    touch "$CONFIG_MARKER"
    echo "✓ Created $DOCKER_CONFIG_FILE"
    return 0
  fi

  if grep -q "cliPluginsExtraDirs" "$DOCKER_CONFIG_FILE" && grep -q '"credsStore"' "$DOCKER_CONFIG_FILE"; then
    echo "✓ $DOCKER_CONFIG_FILE already configured"
    return 0
  fi

  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would add cliPluginsExtraDirs / credsStore to $DOCKER_CONFIG_FILE"
    return 0
  fi

  if ! command -v python3 &>/dev/null; then
    echo "⚠ python3 not found; add this to $DOCKER_CONFIG_FILE by hand:"
    echo "    \"cliPluginsExtraDirs\": [\"$PLUGIN_DIR\"], \"credsStore\": \"osxkeychain\""
    return 0
  fi
  python3 - "$DOCKER_CONFIG_FILE" "$PLUGIN_DIR" <<'PY'
import json, sys
path, plugin_dir = sys.argv[1], sys.argv[2]
with open(path) as f:
    cfg = json.load(f)
dirs = cfg.setdefault("cliPluginsExtraDirs", [])
if plugin_dir not in dirs:
    dirs.append(plugin_dir)
# only switch credential storage when nothing is stored in plain text yet
if "credsStore" not in cfg and not cfg.get("auths"):
    cfg["credsStore"] = "osxkeychain"
with open(path, "w") as f:
    json.dump(cfg, f, indent="\t")
    f.write("\n")
PY
  echo "✓ Updated $DOCKER_CONFIG_FILE"
}

install_docker() {
  echo "=== Docker (colima) ==="
  install_brew_for docker colima docker docker-compose docker-buildx docker-credential-helper
  echo ""

  echo "=== Docker CLI Configuration ==="
  configure_docker_cli
  echo ""

  echo "=== colima VM ==="
  if colima_profile_exists; then
    if colima_running; then
      echo "✓ colima profile '$COLIMA_PROFILE' already running"
    elif [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would start existing colima profile '$COLIMA_PROFILE'"
    else
      echo "Starting colima profile '$COLIMA_PROFILE'..."
      colima start --profile "$COLIMA_PROFILE"
      echo "✓ colima started"
    fi
  elif [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would create and start colima profile '$COLIMA_PROFILE'" \
         "(vz, virtiofs, Rosetta, ${COLIMA_CPU} CPU, ${COLIMA_MEMORY} GiB, ${COLIMA_DISK} GiB disk)"
  else
    echo "Creating colima profile '$COLIMA_PROFILE' (${COLIMA_CPU} CPU, ${COLIMA_MEMORY} GiB, ${COLIMA_DISK} GiB disk)..."
    # rootful docker, Virtualization.framework, virtiofs mounts, Rosetta for
    # linux/amd64 images; DOTX_COLIMA_CPU/MEMORY/DISK override the sizes
    colima start --profile "$COLIMA_PROFILE" --runtime docker \
      --vm-type vz --vz-rosetta --mount-type virtiofs \
      --cpu "$COLIMA_CPU" --memory "$COLIMA_MEMORY" --disk "$COLIMA_DISK"
    mkdir -p "$STATE_DIR"
    touch "$PROFILE_MARKER"
    echo "✓ colima profile created and started"
  fi
  echo ""
  echo "Note: colima does not start at login; run \`colima start\` after a reboot,"
  echo "      or \`brew services start colima\` to start it automatically."
  echo ""
}

uninstall_docker() {
  echo "=== Docker (colima) Uninstall ==="

  if colima_profile_exists; then
    if [ -f "$PROFILE_MARKER" ]; then
      if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "  [DRY-RUN] Would stop and delete colima profile '$COLIMA_PROFILE' (all images and containers in it)"
      else
        echo "  ⚠ Deleting colima profile '$COLIMA_PROFILE' and every image and container in it"
        colima_running && colima stop --profile "$COLIMA_PROFILE"
        colima delete --profile "$COLIMA_PROFILE" --force
        rm -f "$PROFILE_MARKER"
        if [ -z "$(colima list 2>/dev/null | awk 'NR > 1')" ]; then
          rm -rf "$HOME/.colima"
          echo "  Removed ~/.colima"
        fi
        echo "  ✓ colima profile deleted"
      fi
    else
      echo "  Note: colima profile '$COLIMA_PROFILE' existed before dotx; kept (\`colima delete\` removes it)"
    fi
  fi

  if [ -f "$CONFIG_MARKER" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would remove $DOCKER_CONFIG_FILE (created by dotx)"
    else
      rm -f "$DOCKER_CONFIG_FILE" "$CONFIG_MARKER"
      echo "  Removed $DOCKER_CONFIG_FILE"
      # the CLI's own context store (colima already removed its entry) and the
      # directory itself, when nothing else is in there
      rm -rf "$HOME/.docker/contexts"
      rmdir "$HOME/.docker" 2>/dev/null && echo "  Removed ~/.docker" || true
    fi
  elif [ -f "$DOCKER_CONFIG_FILE" ]; then
    echo "  Note: $DOCKER_CONFIG_FILE existed before dotx; kept"
  fi

  uninstall_brew_for docker
  if [ "${DRY_RUN:-false}" != "true" ]; then
    rmdir "$STATE_DIR" 2>/dev/null || true
  fi
  echo ""
}

MODE="${1:-install}"
case "$MODE" in
  install)   install_docker ;;
  uninstall) uninstall_docker ;;
  *) echo "Unknown mode: $MODE"; exit 1 ;;
esac
