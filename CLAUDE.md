# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **cross-platform dotfiles management tool** designed for **macOS** and **Ubuntu/Debian Linux** using a bootstrap-based architecture.

**Purpose**: Automate the setup of development environments with consistent configurations across platforms while handling platform-specific requirements (like Homebrew for macOS and APT for Ubuntu).

## Architecture

The system uses a **bootstrap pattern** with **platform-specific delegation**:

```
User → bootstrap.sh → platform/{macos,ubuntu}/setup.sh → {packages, configs, plugins}
```

### Design Principles

1. **Single Entry Point**: `bootstrap.sh` detects the platform and delegates to platform-specific setup scripts
2. **Common Configs**: Cross-platform dotfiles (`.vimrc`, `.gitconfig`, `.tmux.conf`) stored in `common/`
3. **Platform Separation**: macOS and Ubuntu have separate directories with platform-specific logic
4. **Shared Utilities**: Common functions (platform detection, symlink management) in `utils/`
5. **Two-Mode Interface**: `--install` and `--uninstall` with `--dry-run` for safe preview
6. **Pure Bash**: No Makefile, all logic in shell scripts

## Core Commands

### Main Entry Point

```bash
# Install everything (detect platform automatically)
./bootstrap.sh
./bootstrap.sh --install

# Install specific components only
./bootstrap.sh --install vim git
./bootstrap.sh --install bash
./bootstrap.sh vim tmux  # --install is default mode
./bootstrap.sh pyenv pipx  # Install package-only components

# Remove everything (dotfiles and packages)
./bootstrap.sh --uninstall

# Remove specific components only
./bootstrap.sh --uninstall vim
./bootstrap.sh --uninstall bash nvm
./bootstrap.sh --uninstall pyenv pipx

# Preview changes without applying (dry-run mode)
./bootstrap.sh --dry-run
./bootstrap.sh --dry-run --install vim git
./bootstrap.sh --dry-run --uninstall bash

# Show help
./bootstrap.sh --help
```

### Available Components

The following components can be selectively installed or uninstalled:

- `vim` - Vim editor with vim-plug and plugins
- `git` - Git version control configuration
- `tmux` - Tmux terminal multiplexer
- `bash` - Bash shell configuration with bash-git-prompt
- `nvm` - Node Version Manager
- `pyenv` - Python version manager (package only, no configuration)
- `pipx` - Python application installer (package only, no configuration)
- `all` - All components (default if none specified)

### Platform-Specific (Advanced)

```bash
# Run macOS setup directly (all components)
bash platform/macos/setup.sh install
bash platform/macos/setup.sh uninstall

# Run macOS setup with specific components
bash platform/macos/setup.sh install vim git
bash platform/macos/setup.sh uninstall bash

# Run Ubuntu setup directly (all components)
bash platform/ubuntu/setup.sh install
bash platform/ubuntu/setup.sh uninstall

# Run Ubuntu setup with specific components
bash platform/ubuntu/setup.sh install tmux nvm
bash platform/ubuntu/setup.sh uninstall vim
```

## Directory Structure

```
dotx/
├── bootstrap.sh                    # Main entry point (~100 lines)
├── common/                         # Cross-platform configs and setup
│   ├── bash/
│   │   ├── .bashrc                # Main bash configuration (shared)
│   │   ├── .bash_profile          # Sources .bashrc for login shells
│   │   ├── WonderChang.bgptheme   # Custom bash-git-prompt theme
│   │   └── setup.sh               # Bash setup (symlinks + bash-git-prompt)
│   ├── git/
│   │   ├── .gitconfig             # Git configuration
│   │   └── setup.sh               # Git setup (symlinks)
│   ├── nvm/
│   │   └── setup.sh               # NVM setup (installation)
│   ├── vim/
│   │   ├── .vimrc                 # Vim configuration
│   │   └── setup.sh               # Vim setup (symlinks + vim-plug)
│   └── tmux/
│       ├── .tmux.conf             # Tmux configuration
│       ├── .tmux.conf.local       # Tmux local overrides
│       └── setup.sh               # Tmux setup (symlinks)
├── platform/                       # Platform-specific setup
│   ├── macos/
│   │   ├── setup.sh               # macOS orchestrator (includes inline package management)
│   │   ├── homebrew.sh            # Homebrew installer (prerequisite)
│   │   └── .bashrc.macos          # macOS-specific bash configuration
│   └── ubuntu/
│       ├── setup.sh               # Ubuntu orchestrator (includes inline package management)
│       ├── apt.sh                 # APT update
│       └── .bashrc.ubuntu         # Ubuntu-specific bash configuration
└── utils/                          # Shared utilities
    ├── detect.sh                  # Platform detection
    └── symlink.sh                 # Symlink management with auto-backup
```

## How It Works

### 1. Bootstrap Flow

```bash
bootstrap.sh [--install|--uninstall] [--dry-run] [components...]
  ↓
  1. Parse arguments:
     - Mode: install/uninstall (default: install)
     - Dry-run flag: true/false (default: false)
     - Components: vim, git, tmux, bash, nvm, pyenv, pipx, all
  ↓
  2. Detect platform (macOS or Ubuntu)
  ↓
  3. Export DRY_RUN environment variable for child scripts
  ↓
  4. Delegate to platform/macos/setup.sh or platform/ubuntu/setup.sh with components
  ↓
  5. Platform setup orchestrates (for each component):
     - Install package (inline, if needed) - respects DRY_RUN
     - Setup tool configuration (calls common/{vim,git,tmux,bash,nvm}/setup.sh) - respects DRY_RUN
     - Package-only components (pyenv, pipx) install package without configuration - respects DRY_RUN
```

**Key Architecture Changes**:
1. **Inline Package Management**: Packages are installed right before each tool's setup, rather than in a separate batch step. This ensures each component is fully installed and configured before moving to the next one.
2. **Dry-Run Support**: All operations check the `DRY_RUN` environment variable and preview changes instead of applying them when enabled.

### 2. Selective Component Installation

The system supports installing or uninstalling individual components instead of all tools at once:

**How it works**:
```bash
# Install only vim and git
./bootstrap.sh --install vim git
```

**Component selection logic** (`should_install_component()` function):
1. **No components specified** → Install/uninstall ALL components (default behavior)
   ```bash
   ./bootstrap.sh --install  # Installs everything
   ```

2. **'all' specified** → Install/uninstall ALL components
   ```bash
   ./bootstrap.sh --install all  # Installs everything
   ```

3. **Specific components** → Install/uninstall ONLY those components
   ```bash
   ./bootstrap.sh --install vim bash  # Only vim and bash
   ```

**Implementation** (in `platform/*/setup.sh`):
```bash
# Check if a component should be processed
should_install_component() {
  local component="$1"

  # If no components specified, install all
  if [ ${#COMPONENTS[@]} -eq 0 ]; then
    return 0
  fi

  # Check if 'all' is in components
  for c in "${COMPONENTS[@]}"; do
    if [ "$c" = "all" ]; then
      return 0
    fi
  done

  # Check if specific component is in list
  for c in "${COMPONENTS[@]}"; do
    if [ "$c" = "$component" ]; then
      return 0
    fi
  done

  return 1
}

# Conditional installation
if should_install_component "vim"; then
  bash "$PROJECT_ROOT/common/vim/setup.sh" install
fi
```

**Benefits**:
- Install only what you need on a new machine
- Update specific tools without affecting others
- Remove unwanted components while keeping others
- Faster installation for minimal setups

### 3. Platform-Specific Setup (macOS)

**platform/macos/setup.sh**:

The setup script now installs packages inline, right before each tool's configuration:

```bash
install_macos() {
  # 1. Install Homebrew (prerequisite)
  bash homebrew.sh

  # 2. Install tools with their packages (inline)
  if should_install_component "vim"; then
    # Note: vim comes with macOS, using system vim
    bash common/vim/setup.sh install
  fi

  if should_install_component "git"; then
    # Note: git comes with macOS Xcode Command Line Tools
    bash common/git/setup.sh install
  fi

  if should_install_component "tmux"; then
    install_brew_package "tmux"      # Install package first
    bash common/tmux/setup.sh install # Then setup configuration
  fi

  if should_install_component "bash"; then
    bash common/bash/setup.sh install
    # Platform-specific bash config
    create_symlink "$SCRIPT_DIR/.bashrc.macos" "$HOME/.bashrc.local"
  fi

  if should_install_component "nvm"; then
    bash common/nvm/setup.sh install
  fi

  if should_install_component "pyenv"; then
    install_brew_package "pyenv"     # Package-only component
  fi

  if should_install_component "pipx"; then
    install_brew_package "pipx"      # Package-only component
  fi
}
```

**Package Management Helpers** (in setup.sh):
```bash
install_brew_package() {
  local package="$1"

  if brew list "$package" &>/dev/null; then
    echo "✓ $package already installed"
  else
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would install $package via Homebrew"
    else
      echo "Installing $package..."
      brew install "$package"
      echo "✓ $package installed"
    fi
  fi
}

uninstall_brew_package() {
  local package="$1"

  if brew list "$package" &>/dev/null; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would uninstall $package via Homebrew"
    else
      echo "Uninstalling $package..."
      brew uninstall "$package"
      echo "✓ $package uninstalled"
    fi
  else
    echo "✓ $package not installed"
  fi
}
```

**platform/macos/homebrew.sh**:
- Checks if Homebrew is installed
- Runs official installer if not present (skipped in dry-run mode)
- Runs `brew doctor` to verify installation
- Supports dry-run mode to preview installation

**platform/macos/.bashrc.macos**:
- macOS-specific bash configuration (symlinked to `~/.bashrc.local`)
- Trash directory path for macOS (`$HOME/.Trash`)
- Homebrew environment initialization
- macOS-specific aliases (TextEdit)
- nvm loading from Homebrew path (`/opt/homebrew/opt/nvm`)

### 4. Uninstall Flow

```bash
bootstrap.sh --uninstall [components...]
  ↓
  1. Detect platform (macOS or Ubuntu)
  ↓
  2. Delegate to platform/macos/setup.sh or platform/ubuntu/setup.sh
  ↓
  3. Platform uninstall orchestrates (for each component):
     - Tool uninstall (calls common/{vim,git,tmux,bash,nvm}/setup.sh uninstall)
     - Package uninstall (inline, right after tool cleanup)
```

**Key Points**:
- Each tool's `setup.sh` removes its own symlinks and configurations first
- Package is uninstalled after configuration cleanup (reverse order from install)
- Ensures clean removal of both configuration and package

### 5. Platform-Specific Setup (Ubuntu)

**platform/ubuntu/setup.sh**:

The setup script now installs packages inline, right before each tool's configuration:

```bash
install_ubuntu() {
  # 1. Update APT
  bash apt.sh

  # 2. Install tools with their packages (inline)
  if should_install_component "vim"; then
    install_apt_package "vim"         # Install package first
    bash common/vim/setup.sh install  # Then setup configuration
  fi

  if should_install_component "git"; then
    install_apt_package "git"
    bash common/git/setup.sh install
  fi

  if should_install_component "tmux"; then
    install_apt_package "tmux"
    bash common/tmux/setup.sh install
  fi

  if should_install_component "bash"; then
    bash common/bash/setup.sh install
    # Platform-specific bash config
    create_symlink "$SCRIPT_DIR/.bashrc.ubuntu" "$HOME/.bashrc.local"
  fi

  if should_install_component "nvm"; then
    bash common/nvm/setup.sh install
  fi

  if should_install_component "pyenv"; then
    install_apt_package "pyenv"      # Package-only component
  fi

  if should_install_component "pipx"; then
    install_apt_package "pipx"       # Package-only component
  fi
}
```

**Package Management Helpers** (in setup.sh):
```bash
install_apt_package() {
  local package="$1"

  if dpkg -l | grep -q "^ii  $package "; then
    echo "✓ $package already installed"
  else
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would install $package via APT"
    else
      echo "Installing $package..."
      sudo apt-get install -y "$package"
      echo "✓ $package installed"
    fi
  fi
}

uninstall_apt_package() {
  local package="$1"

  if dpkg -l | grep -q "^ii  $package "; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would uninstall $package via APT"
    else
      echo "Uninstalling $package..."
      sudo apt-get remove -y "$package"
      echo "✓ $package uninstalled"
    fi
  else
    echo "✓ $package not installed"
  fi
}
```

**platform/ubuntu/apt.sh**:
- Runs `sudo apt-get update` to refresh package lists (skipped in dry-run mode)
- Supports dry-run mode to preview update operation

**platform/ubuntu/.bashrc.ubuntu**:
- Ubuntu-specific bash configuration (symlinked to `~/.bashrc.local`)
- Trash directory path for Ubuntu (`$HOME/.local/share/Trash/files`)
- APT package management aliases
- Ubuntu-specific color support (dircolors)
- Snap bin PATH configuration
- nvm loading from standard installation (`$HOME/.nvm`)

### 6. Tool Setup Scripts

Each tool in `common/` has its own setup script that handles platform-independent configuration:

**common/vim/setup.sh**:
- Creates symlink: `~/.vimrc` → `common/vim/.vimrc` (dry-run supported)
- Installs vim-plug plugin manager (dry-run supported)
- Auto-installs vim plugins via PlugInstall (dry-run supported)
- Uninstall removes vim-plug and plugins directory (dry-run supported)

**common/git/setup.sh**:
- Creates symlink: `~/.gitconfig` → `common/git/.gitconfig` (dry-run supported via symlink.sh)

**common/nvm/setup.sh**:
- Installs nvm (Node Version Manager) version 0.40.1 (dry-run supported)
- Downloads and installs to `~/.nvm` via official installer (dry-run supported)
- Platform-specific loading configs in `.bashrc.macos` and `.bashrc.ubuntu`
- Uninstall removes `~/.nvm` directory (dry-run supported)

**common/tmux/setup.sh**:
- Creates symlinks (dry-run supported):
  - `~/.tmux.conf` → `common/tmux/.tmux.conf`
  - `~/.tmux.conf.local` → `common/tmux/.tmux.conf.local`
- Installs powerline fonts (key dependency for tmux, dry-run supported):
  - Clones https://github.com/powerline/fonts.git to temp directory
  - Runs `./install.sh` from the fonts repo
  - Cleans up temp directory
- Uninstall also removes powerline fonts via `./uninstall.sh` (dry-run supported)

**common/bash/setup.sh**:
- Creates symlinks for bash configuration (dry-run supported):
  - `~/.bashrc` → `common/bash/.bashrc` (main configuration)
  - `~/.bash_profile` → `common/bash/.bash_profile` (sources .bashrc for login shells)
- Installs bash-git-prompt (version 2.7.1, dry-run supported):
  - Downloads from GitHub releases
  - Installs to `~/.bash-git-prompt`
  - Symlinks custom WonderChang theme if available
- `.bashrc` contains:
  - Platform-independent settings (aliases, functions, environment variables)
  - bash-git-prompt integration with WonderChang theme
  - Sources `~/.bashrc.local` for platform-specific or user customizations
- Same bash files used on both macOS and Ubuntu
- Platform scripts symlink their specific configs as `~/.bashrc.local`:
  - macOS: `~/.bashrc.local` → `platform/macos/.bashrc.macos`
  - Ubuntu: `~/.bashrc.local` → `platform/ubuntu/.bashrc.ubuntu`
- Uninstall removes bash-git-prompt directory (dry-run supported)

### 7. Shared Utilities

**utils/detect.sh**:
```bash
detect_platform() {
  case "$(uname -s)" in
    Darwin*) echo "macos" ;;
    Linux*)
      if command -v apt-get &>/dev/null; then
        echo "ubuntu"
      else
        echo "unsupported"
        exit 1
      fi ;;
    *) echo "unsupported"; exit 1 ;;
  esac
}
```

**utils/symlink.sh**:
```bash
create_symlink() {
  local source="$1"
  local target="$2"

  # 1. Check if symlink already exists and is correct (idempotent check)
  if [ -L "$target" ]; then
    local current_source=$(readlink "$target")

    if [ "$current_source" = "$source" ]; then
      echo "  ✓ Symlink already correct: $target → $source"
      return 0  # Skip unnecessary work - truly idempotent!
    else
      # Symlink exists but points to wrong source - needs update
      if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "  [DRY-RUN] Would update symlink: $target"
        echo "      Current: $target → $current_source"
        echo "      New:     $target → $source"
      else
        echo "  Updating symlink: $target"
        echo "      Old: $current_source → New: $source"
        rm "$target"
      fi
    fi
  # 2. Backup existing regular file (not a symlink)
  elif [ -e "$target" ]; then
    local backup="$target.backup.$(date +%Y%m%d_%H%M%S)"
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would backup existing file: $target → $backup"
    else
      echo "  Backing up existing file: $target → $backup"
      mv "$target" "$backup"
    fi
  fi

  # 3. Create new symlink (only if we didn't return early)
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "  [DRY-RUN] Would create symlink: $target → $source"
  else
    ln -s "$source" "$target"
    echo "  Created symlink: $target → $source"
  fi
}

remove_symlink() {
  local target="$1"

  # Remove symlink if it exists
  if [ -L "$target" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would remove symlink: $target"
    else
      rm -f "$target"
      echo "  Removed symlink: $target"
    fi
  elif [ -e "$target" ]; then
    echo "  Warning: $target exists but is not a symlink (skipping)"
  fi
}
```

**Key Features**:
- **Truly Idempotent**: Checks if symlink already points to correct source before doing any work
- **Smart Updates**: Detects when symlink exists but points to wrong source, shows old → new transition
- **No Unnecessary Operations**: Returns early if symlink is already correct, avoiding filesystem churn
- **Clear Feedback**: Distinct messages for "already correct" (✓), "updating", "creating", and "backing up"

**Environment Variables**:
- `DRY_RUN`: Set to "true" to preview operations without making changes. Exported by bootstrap.sh and available to all child scripts.

### 8. Dry-Run Implementation

The dry-run mechanism allows previewing all changes before applying them, providing a safe way to verify configurations.

**How It Works**:
1. User passes `--dry-run` flag to `bootstrap.sh`
2. Bootstrap script sets `DRY_RUN=true` and exports it as an environment variable
3. All child scripts inherit the `DRY_RUN` variable
4. Each operation checks `${DRY_RUN:-false}` before executing
5. When true, operations print `[DRY-RUN] Would...` messages instead of executing

**What Gets Previewed**:
- **Package Operations**: Homebrew/APT package installations and removals
- **Symlink Operations**: File backups, symlink creations, and removals
- **Downloads**: vim-plug, bash-git-prompt, nvm, powerline fonts
- **File Operations**: Directory creations and deletions
- **Script Executions**: Homebrew installer, plugin managers

**Implementation Pattern**:
```bash
# For package installations
if [ "${DRY_RUN:-false}" = "true" ]; then
  echo "[DRY-RUN] Would install $package via Homebrew"
else
  brew install "$package"
fi

# For file operations
if [ "${DRY_RUN:-false}" = "true" ]; then
  echo "[DRY-RUN] Would download and install nvm"
else
  curl -o- "https://..." | bash
fi

# For deletions
if [ "${DRY_RUN:-false}" = "true" ]; then
  echo "  [DRY-RUN] Would remove directory: $dir"
else
  rm -rf "$dir"
fi
```

**Coverage**:
- ✅ `bootstrap.sh` - Exports DRY_RUN variable
- ✅ `utils/symlink.sh` - Symlink creation/removal
- ✅ `platform/macos/setup.sh` - Package management helpers
- ✅ `platform/macos/homebrew.sh` - Homebrew installation
- ✅ `platform/ubuntu/setup.sh` - Package management helpers
- ✅ `platform/ubuntu/apt.sh` - APT updates
- ✅ `common/vim/setup.sh` - vim-plug and plugin installation
- ✅ `common/git/setup.sh` - Uses symlink.sh (automatic support)
- ✅ `common/tmux/setup.sh` - Powerline fonts installation
- ✅ `common/bash/setup.sh` - bash-git-prompt installation
- ✅ `common/nvm/setup.sh` - nvm installation

## What Gets Installed

### Common (Both Platforms)

- **Dotfiles** (symlinked from `common/`):
  - `~/.vimrc` → Vim configuration
  - `~/.gitconfig` → Git configuration
  - `~/.tmux.conf` → Tmux configuration
  - `~/.tmux.conf.local` → Tmux local overrides
  - `~/.bashrc` → Main bash configuration (platform-independent)
  - `~/.bash_profile` → Bash login shell (sources .bashrc)

- **vim-plug** (plugin manager):
  - Downloaded from official repository
  - Installed to `~/.vim/autoload/plug.vim`

- **Vim Plugins** (via vim-plug):
  - Automatically installed on first run

- **Powerline Fonts** (for tmux):
  - Installed from official GitHub repository
  - Key dependency for tmux theme/statusline
  - Includes install and uninstall scripts

- **bash-git-prompt** (Git prompt for bash):
  - Version 2.7.1 from GitHub releases
  - Installed to `~/.bash-git-prompt`
  - Custom WonderChang theme symlinked to themes directory

- **nvm** (Node Version Manager):
  - Version 0.40.1 from official installer
  - Installed to `~/.nvm`
  - Platform-specific loading in `.bashrc.local`

- **pyenv** (Python Version Manager):
  - Package-only component (no configuration files)
  - Optional, can be selectively installed

- **pipx** (Python Application Installer):
  - Package-only component (no configuration files)
  - Optional, can be selectively installed

### macOS-Specific

- **Homebrew** (package manager):
  - Installed if not present
  - Used to install packages

- **Packages** (via Homebrew):
  - tmux (conditionally installed with tmux component)
  - pyenv (optional, package-only component)
  - pipx (optional, package-only component)

- **Platform-Specific Bash Config**:
  - `~/.bashrc.local` → `platform/macos/.bashrc.macos` (Homebrew setup, macOS aliases, nvm)

### Ubuntu-Specific

- **APT** (package manager):
  - Updated before package installation

- **Packages** (via APT):
  - vim (conditionally installed with vim component)
  - tmux (conditionally installed with tmux component)
  - git (conditionally installed with git component)
  - pyenv (optional, package-only component)
  - pipx (optional, package-only component)

- **Platform-Specific Bash Config**:
  - `~/.bashrc.local` → `platform/ubuntu/.bashrc.ubuntu` (APT aliases, dircolors, snap PATH, nvm)

## Safety Features

### Dry-Run Mode
Preview all changes before applying them:
- `--dry-run`: Shows what would be installed/uninstalled without making any changes
- Displays all operations: package installations, symlink creations, file downloads
- Safe way to verify configuration before running on production machines
- Works with both `--install` and `--uninstall` modes
- Example: `./bootstrap.sh --dry-run --install vim`

### Auto-Backup
Existing files are automatically backed up before symlinking:
```
~/.vimrc → ~/.vimrc.backup.YYYYMMDD_HHMMSS
```

### Uninstall Mode
- `--uninstall`: Removes dotfiles, plugins, AND packages (complete removal)

### Idempotent
- Safe to run multiple times without side effects
- **Smart symlink checking**: Detects when symlinks already point to correct source and skips unnecessary work
- Checks for existing installations before proceeding
- Won't overwrite or duplicate installations
- No filesystem operations when configuration is already correct

## Platform Support

| Platform | Package Manager | Prerequisites |
|----------|----------------|---------------|
| macOS | Homebrew | Auto-installs Homebrew if needed |
| Ubuntu/Debian | APT | Requires `apt-get` (standard on Ubuntu) |

## Adding New Tools/Components

To add a new tool to the setup (e.g., neovim):

### 1. Create Tool Setup Script

Create `common/neovim/setup.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$DOTFILES_DIR/utils/symlink.sh"

install_neovim_setup() {
  echo "=== Neovim Configuration ==="
  create_symlink "$SCRIPT_DIR/init.vim" "$HOME/.config/nvim/init.vim"
  echo "✓ Neovim configuration linked"

  # If you need to download/install plugins, add dry-run check:
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would install neovim plugins"
  else
    # Install plugins here
    echo "✓ Neovim plugins installed"
  fi
}

uninstall_neovim_setup() {
  echo "=== Neovim Uninstall ==="
  remove_symlink "$HOME/.config/nvim/init.vim"

  # Clean up with dry-run support
  if [ -d "$HOME/.config/nvim" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "  [DRY-RUN] Would remove neovim directory"
    else
      rm -rf "$HOME/.config/nvim"
      echo "  Removed neovim directory"
    fi
  fi
}

MODE="${1:-install}"
case "$MODE" in
  install) install_neovim_setup ;;
  uninstall) uninstall_neovim_setup ;;
esac
```

**Important**:
- The `create_symlink` and `remove_symlink` functions from `utils/symlink.sh` automatically support dry-run mode
- For any file operations (downloads, installs, deletes), add explicit `DRY_RUN` checks as shown above

### 2. Add Configuration File

Create `common/neovim/init.vim` with your neovim configuration.

### 3. Update Platform Setup Scripts

**In platform/macos/setup.sh**:
```bash
if should_install_component "neovim"; then
  echo "=== Neovim ==="
  install_brew_package "neovim"           # Install package
  bash "$PROJECT_ROOT/common/neovim/setup.sh" install  # Setup config
  echo ""
fi
```

**In platform/ubuntu/setup.sh**:
```bash
if should_install_component "neovim"; then
  echo "=== Neovim ==="
  install_apt_package "neovim"            # Install package
  bash "$PROJECT_ROOT/common/neovim/setup.sh" install  # Setup config
  echo ""
fi
```

### 4. Update Bootstrap.sh

Add the component to the accepted list:
```bash
vim|git|tmux|bash|nvm|neovim|all)  # Add neovim
  COMPONENTS+=("$1")
  shift
  ;;
```

### 5. Update Component List

Update help text in `bootstrap.sh` and component list in `CLAUDE.md`.

## Adding Package-Only Components (No Configuration)

To add components that only need package installation without configuration files (like `pyenv`, `pipx`):

### 1. Update Bootstrap.sh

Add the component to the accepted list:
```bash
vim|git|tmux|bash|nvm|pyenv|pipx|jq|all)  # Add jq
  COMPONENTS+=("$1")
  shift
  ;;
```

### 2. Update Platform Setup Scripts

**In platform/macos/setup.sh** - Add conditional installation:
```bash
if should_install_component "jq"; then
  echo "=== jq ==="
  install_brew_package "jq"
  echo "✓ jq installed (no configuration needed)"
  echo ""
fi
```

**In platform/ubuntu/setup.sh** - Add conditional installation:
```bash
if should_install_component "jq"; then
  echo "=== jq ==="
  install_apt_package "jq"
  echo "✓ jq installed (no configuration needed)"
  echo ""
fi
```

### 3. Update Component List

Update help text in `bootstrap.sh` and component list in `CLAUDE.md`.

## Adding New Platforms

To add support for a new platform (e.g., Arch Linux):

### 1. Create Platform Directory
```bash
mkdir -p platform/arch
```

### 2. Create Platform Setup Script

Create `platform/arch/setup.sh` with inline package management:

```bash
#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$PROJECT_ROOT/utils/symlink.sh"

COMPONENTS=()

# Package management helpers (with dry-run support)
install_pacman_package() {
  local package="$1"
  if pacman -Q "$package" &>/dev/null; then
    echo "✓ $package already installed"
  else
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would install $package via pacman"
    else
      echo "Installing $package..."
      sudo pacman -S --noconfirm "$package"
      echo "✓ $package installed"
    fi
  fi
}

uninstall_pacman_package() {
  local package="$1"
  if pacman -Q "$package" &>/dev/null; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      echo "[DRY-RUN] Would uninstall $package via pacman"
    else
      echo "Uninstalling $package..."
      sudo pacman -R --noconfirm "$package"
      echo "✓ $package uninstalled"
    fi
  else
    echo "✓ $package not installed"
  fi
}

# Component selection logic
should_install_component() {
  # Same as macos/ubuntu setup.sh
}

install_arch() {
  echo "=== Arch Linux Setup ==="

  # Update package database (with dry-run support)
  if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "[DRY-RUN] Would run: sudo pacman -Sy"
  else
    sudo pacman -Sy
  fi

  # Install components with inline package management
  if should_install_component "vim"; then
    echo "=== Vim ==="
    install_pacman_package "vim"
    bash "$PROJECT_ROOT/common/vim/setup.sh" install
  fi

  # ... repeat for other components
}

uninstall_arch() {
  # Similar structure
}

MODE="${1:-install}"
shift || true
COMPONENTS=("$@")

case "$MODE" in
  install) install_arch ;;
  uninstall) uninstall_arch ;;
esac
```

### 3. Create Platform-Specific Bash Config

Create `platform/arch/.bashrc.arch` with Arch-specific settings.

### 4. Update utils/detect.sh

```bash
detect_platform() {
  case "$(uname -s)" in
    Darwin*) echo "macos" ;;
    Linux*)
      if command -v pacman &>/dev/null; then
        echo "arch"
      elif command -v apt-get &>/dev/null; then
        echo "ubuntu"
      else
        echo "unsupported"
        exit 1
      fi ;;
    *) echo "unsupported"; exit 1 ;;
  esac
}
```

### 5. Update bootstrap.sh

```bash
case "$PLATFORM" in
  macos) bash platform/macos/setup.sh "$MODE" "${COMPONENTS[@]}" ;;
  ubuntu) bash platform/ubuntu/setup.sh "$MODE" "${COMPONENTS[@]}" ;;
  arch) bash platform/arch/setup.sh "$MODE" "${COMPONENTS[@]}" ;;
  *)
    echo "ERROR: Unsupported platform: $PLATFORM"
    exit 1
    ;;
esac
```

### Key Points for New Platforms

- **Inline Package Management**: Use platform-specific package helpers within setup.sh
- **No Separate packages.sh**: All package logic is in setup.sh
- **Component-Based**: Support selective installation with `should_install_component()`
- **Platform-Specific Bash Config**: Create `.bashrc.{platform}` symlinked as `~/.bashrc.local`
- **Dry-Run Support**: All package management helpers and file operations must check `DRY_RUN` environment variable

## Important Notes

- **Internet Required**: For downloading Homebrew, vim-plug, bash-git-prompt, nvm, powerline fonts, and plugins
- **Safe by Default**: Auto-backup before any changes (with timestamp)
- **Dry-Run Available**: Preview all changes with `--dry-run` before applying
- **Idempotent**: Safe to run multiple times without side effects
- **Platform Detection**: Automatic, no user input needed
- **Supported Platforms**: macOS and Ubuntu/Debian Linux only
- **Prerequisites**:
  - macOS: Automatically installs Homebrew if needed
  - Ubuntu: Requires `apt-get` (standard on Ubuntu/Debian)
- **Versions**:
  - vim-plug: 0.14.0
  - bash-git-prompt: 2.7.1
  - nvm: 0.40.1

## Quick Reference

| Task | Command |
|------|---------|
| Install everything | `./bootstrap.sh` or `./bootstrap.sh --install` |
| Install specific components | `./bootstrap.sh --install vim git` |
| Install single component | `./bootstrap.sh vim` |
| Install package-only components | `./bootstrap.sh pyenv pipx` |
| Preview install (dry-run) | `./bootstrap.sh --dry-run` |
| Preview specific install | `./bootstrap.sh --dry-run --install vim git` |
| Remove everything | `./bootstrap.sh --uninstall` |
| Remove specific components | `./bootstrap.sh --uninstall bash nvm` |
| Preview uninstall | `./bootstrap.sh --dry-run --uninstall` |
| Show help | `./bootstrap.sh --help` |
| Available components | `vim`, `git`, `tmux`, `bash`, `nvm`, `pyenv`, `pipx`, `all` |
| macOS setup only | `bash platform/macos/setup.sh install` |
| macOS setup (selective) | `bash platform/macos/setup.sh install vim tmux` |
| Ubuntu setup only | `bash platform/ubuntu/setup.sh install` |
| Ubuntu setup (selective) | `bash platform/ubuntu/setup.sh install git bash` |
| Add tool with config | Create `common/{tool}/setup.sh`, update `platform/*/setup.sh` and `bootstrap.sh` |
| Add package-only component | Add conditional block in `platform/*/setup.sh`, update `bootstrap.sh` |
| Check platform | `source utils/detect.sh && detect_platform` |

## Architecture Benefits

1. **Clear Separation**: Platform-specific logic is isolated
2. **Easy to Extend**: Add new platforms without modifying existing code
3. **Single Entry Point**: User only needs to run `./bootstrap.sh`
4. **Reusable Components**: Utilities are shared across platforms
5. **Maintainable**: Each script has a single, clear responsibility
6. **Testable**: Platform scripts can be tested independently
7. **No Dependencies**: Pure bash, no external tools required (except platform package managers)
8. **Inline Package Management**: Packages installed right before tool setup ensures:
   - **Atomic Operations**: Each tool is fully installed and configured before moving to next
   - **Better Error Handling**: Failures are isolated to specific components
   - **Clear Flow**: Easy to understand "install package → setup config" sequence
   - **Selective Installation**: Only installs packages for requested components
   - **Easier Debugging**: Can see exactly which package+config pair is being processed
9. **Safety First**: Dry-run mode and auto-backup prevent accidental system changes

## Best Practices

### Running on New Machines

1. **Always dry-run first** to verify what will be installed:
   ```bash
   ./bootstrap.sh --dry-run
   ```

2. **Review the output** to ensure it matches your expectations

3. **Run actual installation** after verification:
   ```bash
   ./bootstrap.sh
   ```

4. **Safe to re-run** - The tool is truly idempotent:
   ```bash
   ./bootstrap.sh  # First run: creates symlinks
   ./bootstrap.sh  # Second run: detects everything is correct, skips work
   ```

   Output on second run:
   ```
   ✓ Symlink already correct: /home/user/.vimrc → /path/to/dotx/common/vim/.vimrc
   ✓ vim-plug already installed
   ✓ tmux already installed
   ```

### Selective Installation

1. **Install only what you need** on minimal setups:
   ```bash
   ./bootstrap.sh vim git bash
   ```

2. **Add components later** as needed:
   ```bash
   ./bootstrap.sh nvm pyenv
   ```

### Customization

1. **Platform-specific configs** go in `platform/{macos,ubuntu}/.bashrc.*`
2. **User-specific configs** can be added to `~/.bashrc.local` after installation (won't be tracked)
3. **Common configs** that work on all platforms go in `common/bash/.bashrc`

### Testing Changes

1. **Dry-run before committing** new components or changes:
   ```bash
   ./bootstrap.sh --dry-run --install <new-component>
   ```

2. **Test on both platforms** if adding cross-platform components

3. **Verify uninstall** works correctly:
   ```bash
   ./bootstrap.sh --dry-run --uninstall <component>
   ```

## Troubleshooting

### Symlink Already Exists

**Problem**: "Warning: target exists but is not a symlink"

**Solution**:
- The file exists but isn't a symlink managed by dotx
- Check if it's safe to remove: `ls -la ~/.vimrc`
- Manually backup and remove: `mv ~/.vimrc ~/.vimrc.manual.backup && ./bootstrap.sh vim`

### Package Installation Fails

**Problem**: Homebrew/APT package fails to install

**Solution**:
- macOS: Run `brew doctor` to check Homebrew health
- Ubuntu: Run `sudo apt-get update` manually
- Check internet connection
- Review error messages for specific package issues

### Existing Configurations

**Problem**: Want to preserve existing configs

**Solution**:
- Automatic backups are created with timestamp: `~/.vimrc.backup.YYYYMMDD_HHMMSS`
- Check `~/` for `.backup.` files to restore
- Or use dry-run to see what will be backed up first

### Permission Denied

**Problem**: "Permission denied" when creating symlinks

**Solution**:
- Ensure you have write access to `$HOME`
- Don't run with `sudo` - the script manages user dotfiles
- Platform package installs (APT) will prompt for sudo when needed

### Dry-Run Shows Unexpected Changes

**Problem**: Dry-run output shows unwanted installations

**Solution**:
- Use selective installation to limit scope
- Review which components are specified
- Check if you accidentally specified `all`

## Development Guidelines

When contributing to this project:

1. **Always add dry-run support** to new operations
2. **Use `${DRY_RUN:-false}` pattern** for consistency
3. **Prefix dry-run messages** with `[DRY-RUN]`
4. **Test both dry-run and actual execution** paths
5. **Update CLAUDE.md** with any architectural changes
6. **Follow existing code style** (bash best practices, set -eu, etc.)
7. **Make scripts idempotent** - safe to run multiple times
8. **Add comments** for non-obvious logic
9. **Use absolute paths** when sourcing utilities
10. **Handle errors gracefully** with meaningful messages
