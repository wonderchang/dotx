#!/usr/bin/env bash
# utils/components.sh
# Component tiers and selection, shared by bootstrap.sh and the platform
# setup scripts.
#
# Two tiers:
#   basic    - installed by a plain `./bootstrap.sh` (and removed by a plain
#              `./bootstrap.sh --uninstall`)
#   optional - only touched when named explicitly, e.g. `./bootstrap.sh gcloud`
#
# Selection keywords:
#   (nothing) or `basic`  → the basic set
#   `all`                 → basic + optional, i.e. everything dotx knows
#   component names       → exactly those; `basic gcloud` = basic set + gcloud
#
# The caller sets COMPONENTS=(...) from the command line; it may be empty.

BASIC_COMPONENTS=(vim git tmux bash nvm pyenv pipx uv rust)
OPTIONAL_COMPONENTS=(gcloud)

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

is_basic_component() {
  _in_list "$1" "${BASIC_COMPONENTS[@]}"
}

is_optional_component() {
  _in_list "$1" "${OPTIONAL_COMPONENTS[@]}"
}

# Accepts component names and the selection keywords
is_valid_component() {
  is_basic_component "$1" || is_optional_component "$1" || _in_list "$1" basic all
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

  return 1
}

# One line describing the selection, for the bootstrap header
describe_components() {
  if [ ${#COMPONENTS[@]} -eq 0 ]; then
    echo "basic (${BASIC_COMPONENTS[*]})"
  else
    echo "${COMPONENTS[*]}"
  fi
}
