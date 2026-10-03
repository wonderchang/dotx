#!/usr/bin/env bash
# utils/components.sh
# Component tiers, selection and profile, shared by bootstrap.sh and the
# platform setup scripts.
#
# Three tiers:
#   minimal  - the shell experience and nothing else: vim, git, tmux, htop,
#              bash. Meant for servers, containers, WSL, other people's
#              machines. Same key bindings and aliases, no fonts, no terminal
#              integration, no language toolchains.
#   basic    - minimal + the workstation toolchains; installed by a plain
#              `./bootstrap.sh` (and removed by a plain `./bootstrap.sh --uninstall`)
#   optional - only touched when named explicitly, e.g. `./bootstrap.sh gcloud aws`
#
# Selection keywords:
#   (nothing) or `basic`  → the basic set
#   `minimal`             → the minimal set (and the minimal profile, below)
#   `all`                 → basic + optional, i.e. everything dotx knows
#   component names       → exactly those; `basic gcloud` = basic set + gcloud
#
# Profile: `minimal` installs its components with the stylish parts turned
# off (plain tmux theme instead of powerline, no powerline fonts, no iTerm2
# setup, no machine-specific ~/.gitconfig.local). The choice is remembered in
# ~/.local/state/dotx/profile so that a later `./bootstrap.sh tmux` on a
# minimal machine stays plain; `basic` or `all` switch back to the full
# profile. Component scripts read it as $DOTX_PROFILE ("minimal" or "full").
#
# The caller sets COMPONENTS=(...) from the command line; it may be empty.

MINIMAL_COMPONENTS=(vim git tmux htop bash)
BASIC_COMPONENTS=(vim git tmux htop bash nvm pyenv pipx uv rust)
OPTIONAL_COMPONENTS=(gcloud aws lima docker)
DOTX_PROFILE_FILE="$HOME/.local/state/dotx/profile"

# _in_list needle [item...]
_in_list() {
  local needle="$1" item
  shift
  for item in "$@"; do
    if [ "$item" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

is_minimal_component() {
  _in_list "$1" "${MINIMAL_COMPONENTS[@]}"
}

is_basic_component() {
  _in_list "$1" "${BASIC_COMPONENTS[@]}"
}

is_optional_component() {
  _in_list "$1" "${OPTIONAL_COMPONENTS[@]}"
}

# Accepts component names and the selection keywords
is_valid_component() {
  is_basic_component "$1" || is_optional_component "$1" || _in_list "$1" minimal basic all
}

# Should this component be processed in the current run?
should_install_component() {
  local component="$1"

  # Named explicitly
  if _in_list "$component" ${COMPONENTS[@]+"${COMPONENTS[@]}"}; then
    return 0
  fi

  # `all` selects every component, basic and optional
  if _in_list all ${COMPONENTS[@]+"${COMPONENTS[@]}"}; then
    return 0
  fi

  # Nothing given, or `basic`: the basic set only
  if [ ${#COMPONENTS[@]} -eq 0 ] || _in_list basic ${COMPONENTS[@]+"${COMPONENTS[@]}"}; then
    if is_basic_component "$component"; then
      return 0
    fi
  fi

  # `minimal`: the minimal set only
  if _in_list minimal ${COMPONENTS[@]+"${COMPONENTS[@]}"}; then
    if is_minimal_component "$component"; then
      return 0
    fi
  fi

  return 1
}

# Profile asked for on this command line: "full" (nothing, `basic` or
# `all`), "minimal", or "" when only component names were given, which keeps
# whatever profile is stored.
requested_profile() {
  if _in_list basic ${COMPONENTS[@]+"${COMPONENTS[@]}"} || _in_list all ${COMPONENTS[@]+"${COMPONENTS[@]}"}; then
    echo "full"
  elif _in_list minimal ${COMPONENTS[@]+"${COMPONENTS[@]}"}; then
    echo "minimal"
  elif [ ${#COMPONENTS[@]} -eq 0 ]; then
    echo "full"
  else
    echo ""
  fi
}

# Profile this run works with: the requested one, else the stored one, else full
resolve_profile() {
  local requested stored
  requested=$(requested_profile)
  stored=$(cat "$DOTX_PROFILE_FILE" 2>/dev/null || true)
  echo "${requested:-${stored:-full}}"
}

# Remember the profile after an install of a whole tier
save_profile() {
  local profile="$1"
  [ "${DRY_RUN:-false}" = "true" ] && return 0
  mkdir -p "$(dirname "$DOTX_PROFILE_FILE")"
  echo "$profile" > "$DOTX_PROFILE_FILE"
}

# Forget it after an uninstall of a whole tier
clear_profile() {
  [ "${DRY_RUN:-false}" = "true" ] && return 0
  rm -f "$DOTX_PROFILE_FILE"
  rmdir "$(dirname "$DOTX_PROFILE_FILE")" "$(dirname "$(dirname "$DOTX_PROFILE_FILE")")" 2>/dev/null || true
}

# One line describing the selection, for the bootstrap header
describe_components() {
  if [ ${#COMPONENTS[@]} -eq 0 ]; then
    echo "basic (${BASIC_COMPONENTS[*]})"
  elif [ "${COMPONENTS[*]}" = "minimal" ]; then
    echo "minimal (${MINIMAL_COMPONENTS[*]})"
  else
    echo "${COMPONENTS[*]}"
  fi
}
