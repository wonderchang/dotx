#!/usr/bin/env bash
# platform/macos/brew-common.sh
# Homebrew helpers shared by the macOS setup (source this file).
#
# install_brew_for <component> [--cask] <package>... installs the packages
# that are missing and keeps two kinds of state under ~/.local/state/dotx/brew:
#   <component>  what this component needs, as formula:<name> or cask:<name>
#                (only packages dotx put there; one that was on the machine
#                before dotx is never recorded, and so never removed)
#   _installed   what dotx itself installed, across all components
# uninstall_brew_for <component> removes a package only when no other
# component still lists it and dotx installed it (casks with --zap, as the
# cask's zap stanza is what removes e.g. share/google-cloud-sdk). Same
# reference counting as platform/ubuntu/apt-common.sh, so uninstall stays
# the reverse of install even for a formula two components share.
#
# Runs under the system bash 3.2 on a fresh Mac: no bash 4 features here.

DOTX_BREW_STATE="$HOME/.local/state/dotx/brew"
DOTX_BREW_OWNED="$DOTX_BREW_STATE/_installed"

brew_formula_installed() {
  brew list --formula "$1" &>/dev/null
}

brew_cask_installed() {
  brew list --cask "$1" &>/dev/null
}

# ---- state helpers ----------------------------------------------------------

# State written before _installed existed listed only what each component had
# installed itself; that is exactly the owned set, so build it from them once.
_brew_state_migrate() {
  [ -f "$DOTX_BREW_OWNED" ] && return 0
  [ -d "$DOTX_BREW_STATE" ] || return 0
  local f
  for f in "$DOTX_BREW_STATE"/*; do
    [ -f "$f" ] && cat "$f"
  done 2>/dev/null | LC_ALL=C sort -u > "$DOTX_BREW_OWNED.tmp" || true
  if [ -s "$DOTX_BREW_OWNED.tmp" ]; then
    mv -f "$DOTX_BREW_OWNED.tmp" "$DOTX_BREW_OWNED"
  else
    rm -f "$DOTX_BREW_OWNED.tmp"
  fi
}

_brew_owned() {
  grep -qxF "$1" "$DOTX_BREW_OWNED" 2>/dev/null
}

_brew_record() {  # _brew_record <file> <line>
  mkdir -p "$(dirname "$1")"
  grep -qxF "$2" "$1" 2>/dev/null || echo "$2" >> "$1"
}

_brew_unrecord() {  # _brew_unrecord <file> <line>
  [ -f "$1" ] || return 0
  grep -vxF "$2" "$1" > "$1.tmp" || true
  mv -f "$1.tmp" "$1"
  [ -s "$1" ] || rm -f "$1"
}

# Other components (not <component>) whose manifest lists <entry>
_brew_needed_by() {  # _brew_needed_by <entry> <component>
  local f name
  for f in "$DOTX_BREW_STATE"/*; do
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

# ---- component-level install / uninstall ------------------------------------

# install_brew_for <component> [--cask] <package>...
install_brew_for() {
  local component="$1"
  shift
  local kind="formula"
  if [ "${1:-}" = "--cask" ]; then
    kind="cask"
    shift
  fi
  local manifest="$DOTX_BREW_STATE/$component"
  local package installed missing=()

  _brew_state_migrate
  for package in "$@"; do
    installed=false
    if [ "$kind" = "cask" ]; then
      brew_cask_installed "$package" && installed=true
    else
      brew_formula_installed "$package" && installed=true
    fi
    if [ "$installed" = "true" ]; then
      if _brew_owned "$kind:$package"; then
        echo "✓ $package already installed (shared, now also recorded for $component)"
        [ "${DRY_RUN:-false}" = "true" ] || _brew_record "$manifest" "$kind:$package"
      else
        echo "✓ $package already installed"
      fi
    else
      missing+=("$package")
    fi
  done
  [ ${#missing[@]} -eq 0 ] && return 0

  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would install via Homebrew (recorded for $component): ${missing[*]}"
    return 0
  fi

  echo "Installing ${missing[*]}..."
  if [ "$kind" = "cask" ]; then
    brew install --cask "${missing[@]}"
  else
    brew install "${missing[@]}"
  fi
  for package in "${missing[@]}"; do
    _brew_record "$manifest" "$kind:$package"
    _brew_record "$DOTX_BREW_OWNED" "$kind:$package"
    echo "✓ $package installed"
  done
}

# uninstall_brew_for <component>
uninstall_brew_for() {
  local component="$1"
  local manifest="$DOTX_BREW_STATE/$component"
  local entry kind package others

  _brew_state_migrate
  if [ ! -s "$manifest" ]; then
    echo "✓ No Homebrew packages were installed for $component"
    return 0
  fi

  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    kind="${entry%%:*}"
    package="${entry#*:}"
    others=$(_brew_needed_by "$entry" "$component")
    if [ -n "$others" ]; then
      echo "✓ $package kept (still needed by: $others)"
      continue
    fi
    if ! _brew_owned "$entry"; then
      echo "✓ $package kept (was on the machine before dotx)"
      continue
    fi
    if [ "$kind" = "cask" ]; then
      if ! brew_cask_installed "$package"; then
        echo "✓ $package not installed"
      elif [ "${DRY_RUN:-false}" = "true" ]; then
        echo "[DRY-RUN] Would uninstall cask $package via Homebrew (--zap)"
      else
        echo "Uninstalling $package..."
        brew uninstall --cask --zap "$package"
        echo "✓ $package uninstalled"
        _brew_unrecord "$DOTX_BREW_OWNED" "$entry"
      fi
    else
      if ! brew_formula_installed "$package"; then
        echo "✓ $package not installed"
      elif [ -n "$(brew uses --installed "$package" 2>/dev/null)" ]; then
        # e.g. lima while colima (docker component) is still installed
        echo "⚠ $package is still required by: $(brew uses --installed "$package" | tr '\n' ' ')kept"
      elif [ "${DRY_RUN:-false}" = "true" ]; then
        echo "[DRY-RUN] Would uninstall $package via Homebrew"
      else
        echo "Uninstalling $package..."
        brew uninstall "$package"
        echo "✓ $package uninstalled"
        _brew_unrecord "$DOTX_BREW_OWNED" "$entry"
      fi
    fi
  done < "$manifest"

  if [ "${DRY_RUN:-false}" != "true" ]; then
    rm -f "$manifest"
    rmdir "$DOTX_BREW_STATE" "$(dirname "$DOTX_BREW_STATE")" 2>/dev/null || true
  fi
}
