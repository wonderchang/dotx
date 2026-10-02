#!/usr/bin/env bash
# platform/macos/brew-common.sh
# Homebrew helpers shared by the macOS setup (source this file).
#
# install_brew_for <component> [--cask] <package>... installs the packages
# that are missing and records them in ~/.local/state/dotx/brew/<component>;
# uninstall_brew_for <component> removes exactly those (casks with --zap, as
# the cask's zap stanza is what removes e.g. share/google-cloud-sdk). A
# formula or cask that was already on the machine before dotx is never
# removed, so uninstall stays the reverse of install. Same idea as
# platform/ubuntu/apt-common.sh.
#
# Runs under the system bash 3.2 on a fresh Mac: no bash 4 features here.

DOTX_BREW_STATE="$HOME/.local/state/dotx/brew"

brew_formula_installed() {
  brew list --formula "$1" &>/dev/null
}

brew_cask_installed() {
  brew list --cask "$1" &>/dev/null
}

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
  local package missing=()

  for package in "$@"; do
    if [ "$kind" = "cask" ] && brew_cask_installed "$package"; then
      echo "✓ $package already installed"
    elif [ "$kind" = "formula" ] && brew_formula_installed "$package"; then
      echo "✓ $package already installed"
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
  mkdir -p "$DOTX_BREW_STATE"
  for package in "${missing[@]}"; do
    grep -qxF "$kind:$package" "$manifest" 2>/dev/null || echo "$kind:$package" >> "$manifest"
    echo "✓ $package installed"
  done
}

# uninstall_brew_for <component>
uninstall_brew_for() {
  local component="$1"
  local manifest="$DOTX_BREW_STATE/$component"
  local entry kind package

  if [ ! -s "$manifest" ]; then
    echo "✓ No Homebrew packages were installed for $component"
    return 0
  fi

  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    kind="${entry%%:*}"
    package="${entry#*:}"
    if [ "$kind" = "cask" ]; then
      if ! brew_cask_installed "$package"; then
        echo "✓ $package not installed"
      elif [ "${DRY_RUN:-false}" = "true" ]; then
        echo "[DRY-RUN] Would uninstall cask $package via Homebrew (--zap)"
      else
        echo "Uninstalling $package..."
        brew uninstall --cask --zap "$package"
        echo "✓ $package uninstalled"
      fi
    else
      if ! brew_formula_installed "$package"; then
        echo "✓ $package not installed"
      elif [ "${DRY_RUN:-false}" = "true" ]; then
        echo "[DRY-RUN] Would uninstall $package via Homebrew"
      else
        echo "Uninstalling $package..."
        brew uninstall "$package"
        echo "✓ $package uninstalled"
      fi
    fi
  done < "$manifest"

  if [ "${DRY_RUN:-false}" != "true" ]; then
    rm -f "$manifest"
    rmdir "$DOTX_BREW_STATE" "$(dirname "$DOTX_BREW_STATE")" 2>/dev/null || true
  fi
}
