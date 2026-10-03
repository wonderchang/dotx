#!/usr/bin/env bash
# tests/unit-apt-common.sh
# Exercises the reference-counted APT state in platform/ubuntu/apt-common.sh
# without root or a VM: dpkg-query, apt-cache and sudo are replaced by
# functions that keep a fake package database in a temp dir. Runs on macOS or
# Linux.
#   bash tests/unit-apt-common.sh
# Exit code = number of failed checks.
# Runs with `set -e` like the setup scripts do, so a helper that returns
# non-zero on a harmless path (which once aborted --uninstall all) fails here.
set -eu
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail=0
check() { local label="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS  $label"; else echo "FAIL  $label"; fail=$((fail+1)); fi; }

# --- fake package world --------------------------------------------------------
# installed list, dependency table (pkg: deps), both plain files
INSTALLED="$TMP/installed"
DEPS="$TMP/deps"
printf 'xz-utils\n' > "$INSTALLED"             # pre-existing on the "machine"
cat > "$DEPS" <<'EOF'
build-essential gcc make
gcc cpp
libssl-dev
tk-dev tk8.6
EOF
deps_of() { awk -v p="$1" '$1 == p {for (i = 2; i <= NF; i++) print $i}' "$DEPS"; }
is_installed() { grep -qx "$1" "$INSTALLED"; }
add_pkg() { is_installed "$1" || echo "$1" >> "$INSTALLED"; local d; for d in $(deps_of "$1"); do add_pkg "$d"; done; }
del_pkg() { grep -vx "$1" "$INSTALLED" > "$INSTALLED.n" || true; mv "$INSTALLED.n" "$INSTALLED"; }
# everything installed that depends (transitively) on $1
rdeps_of() { local p; while read -r p; do [ -n "$p" ] || continue; deps_of "$p" | grep -qx "$1" && { echo "$p"; rdeps_of "$p"; }; done < "$INSTALLED"; return 0; }

dpkg-query() {
  local last="${*: -1}"
  case "$last" in
    -f=*) while read -r p; do echo "$p installed"; done < "$INSTALLED" ;;      # list mode
    *)    is_installed "$last" && echo installed || return 1 ;;
  esac
}
apt-cache() {  # apt-cache depends <flags> <pkg>: Depends lines like the real tool
  local p="${*: -1}" d
  for d in $(deps_of "$p"); do is_installed "$d" && echo "  Depends: $d"; done
  return 0
}
sudo() {
  shift 2                                        # DEBIAN_FRONTEND=... apt-get
  local sim=false
  [ "$1" = -s ] && { sim=true; shift; }
  local verb="$1"; shift
  local a r
  case "$verb" in
    install)
      for a in "$@"; do [ "$a" = -y ] || add_pkg "$a"; done ;;
    remove)
      for a in "$@"; do
        [ "$a" = -y ] && continue
        for r in "$a" $(rdeps_of "$a" | sort -u); do
          if [ "$sim" = true ]; then echo "Remv $r [1]"; else del_pkg "$r"; fi
        done
      done ;;
    autoremove) : ;;
  esac
}

source "$ROOT/platform/ubuntu/apt-common.sh"
DOTX_APT_STATE="$TMP/state/apt"
DOTX_APT_OWNED="$DOTX_APT_STATE/_installed"
quiet() { "$@" >/dev/null 2>&1; }
manifest_has() { grep -qx "$2" "$DOTX_APT_STATE/$1"; }

echo "--- install records requested packages and their dependencies"
quiet install_apt_packages_for rust build-essential
check "rust manifest: build-essential" manifest_has rust build-essential
check "rust manifest: gcc (dependency)" manifest_has rust gcc
check "rust manifest: cpp (transitive)" manifest_has rust cpp
check "_installed matches" bash -c "[ \"\$(tr '\n' ' ' < '$DOTX_APT_OWNED')\" = 'build-essential cpp gcc make ' ]"

echo "--- shared dependency: pyenv needs build-essential too, and more"
quiet install_apt_packages_for pyenv build-essential libssl-dev xz-utils tk-dev
check "pyenv manifest: build-essential (shared)" manifest_has pyenv build-essential
check "pyenv manifest: tk8.6 (dependency of tk-dev)" manifest_has pyenv tk8.6
check "pre-existing xz-utils not recorded" bash -c "! grep -qx xz-utils '$DOTX_APT_STATE/pyenv'"

echo "--- uninstall rust: build-essential and its deps stay for pyenv"
quiet uninstall_apt_packages_for rust
check "build-essential still installed" is_installed build-essential
check "gcc still installed (needed by pyenv's build-essential)" is_installed gcc
check "rust manifest gone" test ! -e "$DOTX_APT_STATE/rust"

echo "--- a foreign package depends on one of ours: that one is kept, the rest goes"
echo "mytool libssl-dev" >> "$DEPS"; add_pkg mytool            # user installed later
quiet uninstall_apt_packages_for pyenv
check "libssl-dev kept for mytool"   is_installed libssl-dev
check "mytool untouched"             is_installed mytool
is_installed build-essential && { echo "FAIL  build-essential still there"; fail=$((fail+1)); } || echo "PASS  build-essential removed"
is_installed gcc && { echo "FAIL  gcc still there (explicit removal of deps)"; fail=$((fail+1)); } || echo "PASS  gcc removed"
is_installed tk8.6 && { echo "FAIL  tk8.6 still there"; fail=$((fail+1)); } || echo "PASS  tk8.6 removed"
check "xz-utils kept (pre-existing)" is_installed xz-utils
check "state directory cleaned up"   bash -c "[ ! -e '$DOTX_APT_STATE' ]"

echo "--- dry-run writes nothing"
DRY_RUN=true quiet install_apt_packages_for aws unzip
check "no state written in dry-run" bash -c "[ ! -e '$DOTX_APT_STATE' ]"
check "unzip not installed in dry-run" bash -c "! is_installed unzip"

echo "--- migration of state written before _installed existed"
mkdir -p "$DOTX_APT_STATE"; echo tmux > "$DOTX_APT_STATE/tmux"; add_pkg tmux
quiet uninstall_apt_packages_for tmux
is_installed tmux && { echo "FAIL  old-style manifest: tmux not removed"; fail=$((fail+1)); } || echo "PASS  old-style manifest removed tmux"

echo "RESULT unit-apt-common: $fail failure(s)"
exit $fail
