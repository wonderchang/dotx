#!/usr/bin/env bash
# platform/ubuntu/apt-common.sh
# APT helpers shared by the Ubuntu setup scripts (source this file).
#
# install_apt_packages_for <component> <package>... remembers which of the
# packages were missing before, in ~/.local/state/dotx/apt/<component>, and
# uninstall_apt_packages_for <component> removes exactly those, followed by
# `apt-get autoremove` for the dependencies they pulled in. Packages that were
# already on the machine, and whatever depends on them, are never touched:
# removing a pre-installed xz-utils once took build-essential and dpkg-dev
# with it, and removing the image's own vim and tmux took the ubuntu-server
# metapackage. This is used both for a component's own package (vim, tmux,
# pipx) and for dependencies (pyenv build libraries, unzip for aws, QEMU for
# lima). install_apt_package alone is for the base prerequisites in apt.sh,
# which are never removed.
#
# Installed-state checks go through dpkg-query, not `dpkg -l | grep`, because
# multiarch packages are listed as name:arch (libssl-dev:arm64) there.

DOTX_APT_STATE="$HOME/.local/state/dotx/apt"

apt_installed() {
  [ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" = "installed" ]
}

apt_install() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

apt_remove() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y "$@"
}

# Drop packages that were only installed as dependencies and are now unused
apt_autoremove() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
}

install_apt_package() {
  local package="$1"

  if apt_installed "$package"; then
    echo "✓ $package already installed"
  elif [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would install $package via APT"
  else
    echo "Installing $package..."
    apt_install "$package"
    echo "✓ $package installed"
  fi
}

uninstall_apt_package() {
  local package="$1"

  if ! apt_installed "$package"; then
    echo "✓ $package not installed"
  elif [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would uninstall $package via APT"
  else
    echo "Uninstalling $package..."
    apt_remove "$package"
    echo "✓ $package uninstalled"
  fi
}

# install_apt_packages_for <component> <package>...
# Works out the missing packages first and installs them in one APT call:
# installing one at a time would pull later list entries in as dependencies
# (libreadline-dev brings libncurses-dev) and they would then look
# pre-existing and never be recorded, so uninstall would leave them behind.
install_apt_packages_for() {
  local component="$1"
  shift
  local manifest="$DOTX_APT_STATE/$component"
  local package missing=()

  for package in "$@"; do
    if apt_installed "$package"; then
      echo "✓ $package already installed"
    else
      missing+=("$package")
    fi
  done
  [ ${#missing[@]} -eq 0 ] && return 0

  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would install via APT (recorded for $component): ${missing[*]}"
    return 0
  fi

  echo "Installing ${missing[*]}..."
  apt_install "${missing[@]}"
  mkdir -p "$DOTX_APT_STATE"
  for package in "${missing[@]}"; do
    # APT may substitute a transitional name (libncursesw5-dev → libncurses-dev);
    # only record names dpkg actually knows, or uninstall would skip them.
    if apt_installed "$package"; then
      grep -qxF "$package" "$manifest" 2>/dev/null || echo "$package" >> "$manifest"
      echo "✓ $package installed"
    else
      echo "⚠ $package was substituted by APT and is not recorded for $component; use the real package name"
    fi
  done
}

# uninstall_apt_packages_for <component>
uninstall_apt_packages_for() {
  local component="$1"
  local manifest="$DOTX_APT_STATE/$component"
  local package

  if [ ! -s "$manifest" ]; then
    echo "✓ No APT packages were installed for $component"
    return 0
  fi

  local removed=false
  while IFS= read -r package; do
    [ -n "$package" ] || continue
    uninstall_apt_package "$package"
    apt_installed "$package" || removed=true
  done < "$manifest"

  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would run: sudo apt-get autoremove"
  else
    [ "$removed" = "true" ] && apt_autoremove
    rm -f "$manifest"
    rmdir "$DOTX_APT_STATE" "$(dirname "$DOTX_APT_STATE")" 2>/dev/null || true
  fi
}
