#!/usr/bin/env bash
# platform/ubuntu/apt-common.sh
# APT helpers shared by the Ubuntu setup scripts (source this file).
#
# install_apt_packages_for <component> <package>... installs the packages
# that are missing and records what the APT transaction actually added, the
# requested packages and every dependency they pulled in, under
# ~/.local/state/dotx/apt:
#   <component>  what this component brought onto the machine or needs
#                (a package that was there before dotx is never recorded,
#                and so never removed)
#   _installed   everything dotx installed, across all components
# uninstall_apt_packages_for <component> removes a recorded package when no
# other component still lists it and dotx installed it. The whole set goes
# in one `apt-get remove`, after a simulation: if APT would take a package
# that is not in the set with it (something the user installed later that
# depends on one of ours), the packages that one depends on are kept and
# named. Then `apt-get autoremove` for anything else left over.
#
# Recording the dependencies explicitly, instead of leaving them to
# autoremove, is deliberate: apt 3.x keeps auto-installed packages that an
# installed package merely Suggests (apt itself suggests dpkg-dev, which
# recommends gcc, make and fakeroot), so after removing build-essential the
# compiler stayed behind. Reference counting makes shared dependencies safe:
# build-essential is needed by rust and pyenv, `--uninstall rust` keeps it
# while pyenv is installed, `--uninstall pyenv` then removes it.
#
# Used both for a component's own package (vim, tmux, pipx) and for its
# dependencies (build-essential for rust/pyenv, pyenv build libraries, unzip
# for aws, QEMU for lima). install_apt_package alone is for the base
# prerequisites in apt.sh (curl, git), which are never removed.
#
# Installed-state checks go through dpkg-query, not `dpkg -l | grep`, because
# multiarch packages are listed as name:arch (libssl-dev:arm64) there.

DOTX_APT_STATE="$HOME/.local/state/dotx/apt"
DOTX_APT_OWNED="$DOTX_APT_STATE/_installed"

apt_installed() {
  [ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" = "installed" ]
}

# Sorted list of every package in state "installed"
apt_installed_set() {
  dpkg-query -W -f='${Package} ${db:Status-Status}\n' 2>/dev/null | awk '$2 == "installed" {print $1}' | LC_ALL=C sort -u
}

apt_install() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

apt_remove() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y "$@"
}

# What `apt-get remove <pkgs>` would remove, one package name per line
apt_remove_simulate() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get -s remove "$@" 2>/dev/null | awk '/^Remv / {sub(/:[^:]*$/, "", $2); print $2}'
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

# ---- state helpers ----------------------------------------------------------

# State written before _installed existed listed only what each component had
# installed itself; that is exactly the owned set, so build it from them once.
_apt_state_migrate() {
  [ -f "$DOTX_APT_OWNED" ] && return 0
  [ -d "$DOTX_APT_STATE" ] || return 0
  local f
  for f in "$DOTX_APT_STATE"/*; do
    [ -f "$f" ] && cat "$f"
  done 2>/dev/null | LC_ALL=C sort -u > "$DOTX_APT_OWNED.tmp" || true
  if [ -s "$DOTX_APT_OWNED.tmp" ]; then
    mv -f "$DOTX_APT_OWNED.tmp" "$DOTX_APT_OWNED"
  else
    rm -f "$DOTX_APT_OWNED.tmp"
  fi
}

_apt_owned() {
  grep -qxF "$1" "$DOTX_APT_OWNED" 2>/dev/null
}

_apt_record() {  # _apt_record <file> <line>
  mkdir -p "$(dirname "$1")"
  grep -qxF "$2" "$1" 2>/dev/null || echo "$2" >> "$1"
}

_apt_unrecord() {  # _apt_unrecord <file> <line>
  [ -f "$1" ] || return 0
  grep -vxF "$2" "$1" > "$1.tmp" || true
  mv -f "$1.tmp" "$1"
  [ -s "$1" ] || rm -f "$1"
}

# Other components (not <component>) whose manifest lists <package>
_apt_needed_by() {  # _apt_needed_by <package> <component>
  local f name
  for f in "$DOTX_APT_STATE"/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    [ "$name" = "_installed" ] && continue
    [ "$name" = "$2" ] && continue
    grep -qxF "$1" "$f" 2>/dev/null && printf '%s ' "$name"
  done
  # callers assign the output; under `set -e` a failing last grep would
  # otherwise abort the whole setup script
  return 0
}

# Installed packages that <package> depends on (Depends/Pre-Depends), one per line
_apt_depends_of() {
  apt-cache depends --installed --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances "$1" 2>/dev/null \
    | awk '/Depends:/ {gsub(/[<>|]/, "", $2); sub(/:[^:]*$/, "", $2); print $2}'
  return 0
}

# ---- component-level install / uninstall ------------------------------------

# install_apt_packages_for <component> <package>...
# Works out the missing packages first and installs them in one APT call,
# then records everything that call added (requested packages and their
# dependencies), so uninstall can take exactly that away again.
install_apt_packages_for() {
  local component="$1"
  shift
  local manifest="$DOTX_APT_STATE/$component"
  local package missing=() before after added count

  _apt_state_migrate
  for package in "$@"; do
    if apt_installed "$package"; then
      if _apt_owned "$package"; then
        # dotx installed it for another component: this one needs it too
        echo "✓ $package already installed (shared, now also recorded for $component)"
        [ "${DRY_RUN:-false}" = "true" ] || _apt_record "$manifest" "$package"
      else
        echo "✓ $package already installed"
      fi
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
  before=$(apt_installed_set)
  apt_install "${missing[@]}"
  after=$(apt_installed_set)
  added=$(LC_ALL=C comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after"))
  count=0
  while IFS= read -r package; do
    [ -n "$package" ] || continue
    _apt_record "$manifest" "$package"
    _apt_record "$DOTX_APT_OWNED" "$package"
    count=$((count + 1))
  done <<< "$added"
  for package in "${missing[@]}"; do
    if apt_installed "$package"; then
      echo "✓ $package installed"
    else
      # APT may substitute a transitional name (libncursesw5-dev → libncurses-dev);
      # what it really installed is recorded above under its real name.
      echo "⚠ $package was substituted by APT; use the real package name"
    fi
  done
  [ "$count" -gt ${#missing[@]} ] && echo "  ($((count - ${#missing[@]})) dependencies recorded for $component as well)"
  return 0
}

# uninstall_apt_packages_for <component>
uninstall_apt_packages_for() {
  local component="$1"
  local manifest="$DOTX_APT_STATE/$component"
  local package others candidates=() extra dep moved holders h

  _apt_state_migrate
  if [ ! -s "$manifest" ]; then
    echo "✓ No APT packages were installed for $component"
    return 0
  fi

  # Which recorded packages may go: owned by dotx, needed by nobody else,
  # still installed
  while IFS= read -r package; do
    [ -n "$package" ] || continue
    others=$(_apt_needed_by "$package" "$component")
    if [ -n "$others" ]; then
      echo "✓ $package kept (still needed by: $others)"
    elif ! _apt_owned "$package"; then
      echo "✓ $package kept (was on the machine before dotx)"
    elif ! apt_installed "$package"; then
      [ "${DRY_RUN:-false}" = "true" ] || _apt_unrecord "$DOTX_APT_OWNED" "$package"
    else
      candidates+=("$package")
    fi
  done < "$manifest"

  if [ ${#candidates[@]} -gt 0 ]; then
    # Would APT take anything that is not ours with them? Then something
    # the user installed depends on one of ours: keep what it depends on.
    while :; do
      extra=$(apt_remove_simulate "${candidates[@]}" | grep -vxF -f <(printf '%s\n' "${candidates[@]}") || true)
      [ -z "$extra" ] && break
      moved=false
      while IFS= read -r package; do
        [ -n "$package" ] || continue
        holders=$(_apt_needed_by "$package" "$component")
        for dep in $(_apt_depends_of "$package"); do
          printf '%s\n' "${candidates[@]}" | grep -qxF "$dep" || continue
          if [ -n "$holders" ]; then
            # $package belongs to other components: the dependency follows it
            # into their manifests, so it goes when the last of them goes
            echo "✓ $dep kept (needed by $package, now recorded for: $holders)"
            if [ "${DRY_RUN:-false}" != "true" ]; then
              for h in $holders; do _apt_record "$DOTX_APT_STATE/$h" "$dep"; done
            fi
          else
            # $package is the user's: the dependency is theirs now, dotx stops tracking it
            echo "✓ $dep kept (needed by $package, which dotx did not install; no longer tracked)"
            [ "${DRY_RUN:-false}" = "true" ] || _apt_unrecord "$DOTX_APT_OWNED" "$dep"
          fi
          # `|| true`: grep exits 1 when nothing is left, which `set -e` would treat as failure
          candidates=($(printf '%s\n' "${candidates[@]}" | grep -vxF "$dep" || true))
          moved=true
        done
      done <<< "$extra"
      if [ "$moved" != "true" ]; then
        echo "⚠ APT would also remove $(echo "$extra" | tr '\n' ' '); leaving the packages of $component installed"
        candidates=()
        break
      fi
      [ ${#candidates[@]} -eq 0 ] && break
    done
  fi

  if [ ${#candidates[@]} -eq 0 ]; then
    [ "${DRY_RUN:-false}" = "true" ] || rm -f "$manifest"
    rmdir "$DOTX_APT_STATE" "$(dirname "$DOTX_APT_STATE")" 2>/dev/null || true
    return 0
  fi

  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would uninstall via APT: ${candidates[*]}"
    echo "[DRY-RUN] Would run: sudo apt-get autoremove"
    return 0
  fi

  echo "Uninstalling ${candidates[*]}..."
  apt_remove "${candidates[@]}"
  for package in "${candidates[@]}"; do
    apt_installed "$package" || _apt_unrecord "$DOTX_APT_OWNED" "$package"
  done
  echo "✓ ${#candidates[@]} package(s) of $component uninstalled"
  apt_autoremove
  rm -f "$manifest"
  rmdir "$DOTX_APT_STATE" "$(dirname "$DOTX_APT_STATE")" 2>/dev/null || true
}
