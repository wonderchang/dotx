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
5. **Two-Mode Interface**: `--install` and `--uninstall` (with optional `--purge`)
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
bootstrap.sh [--install|--uninstall] [components...]
  ↓
  1. Parse mode (install/uninstall) and components (vim, git, tmux, bash, nvm, pyenv, pipx, all)
  ↓
  2. Detect platform (macOS or Ubuntu)
  ↓
  3. Delegate to platform/macos/setup.sh or platform/ubuntu/setup.sh with components
  ↓
  4. Platform setup orchestrates (for each component):
     - Install package (inline, if needed)
     - Setup tool configuration (calls common/{vim,git,tmux,bash,nvm}/setup.sh for config-based components)
     - Package-only components (pyenv, pipx) install package without configuration
```

**Key Architecture Change**: Packages are now installed inline, right before each tool's setup, rather than in a separate batch step. This ensures each component is fully installed and configured before moving to the next one.

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
  # Checks if package is installed: brew list <package>
  # Installs if missing: brew install <package>
}

uninstall_brew_package() {
  # Checks if package exists
  # Uninstalls: brew uninstall <package>
}
```

**platform/macos/homebrew.sh**:
- Checks if Homebrew is installed
- Runs official installer if not present
- Runs `brew doctor` to verify

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
  # Checks if package is installed: dpkg -l | grep <package>
  # Installs if missing: sudo apt-get install -y <package>
}

uninstall_apt_package() {
  # Checks if package exists
  # Uninstalls: sudo apt-get remove -y <package>
}
```

**platform/ubuntu/apt.sh**:
- Runs `sudo apt-get update` to refresh package lists

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
- Creates symlink: `~/.vimrc` → `common/vim/.vimrc`
- Installs vim-plug plugin manager
- Auto-installs vim plugins

**common/git/setup.sh**:
- Creates symlink: `~/.gitconfig` → `common/git/.gitconfig`

**common/nvm/setup.sh**:
- Installs nvm (Node Version Manager) version 0.40.1
- Downloads and installs to `~/.nvm`
- Platform-specific loading configs in `.bashrc.macos` and `.bashrc.ubuntu`

**common/tmux/setup.sh**:
- Creates symlinks: `~/.tmux.conf` → `common/tmux/.tmux.conf`
- Creates symlinks: `~/.tmux.conf.local` → `common/tmux/.tmux.conf.local`
- Installs powerline fonts (key dependency for tmux):
  - Clones https://github.com/powerline/fonts.git to temp directory
  - Runs `./install.sh` from the fonts repo
  - Cleans up temp directory
- Uninstall also removes powerline fonts via `./uninstall.sh`

**common/bash/setup.sh**:
- Creates symlinks for bash configuration:
  - `~/.bashrc` → `common/bash/.bashrc` (main configuration)
  - `~/.bash_profile` → `common/bash/.bash_profile` (sources .bashrc for login shells)
- Installs bash-git-prompt (version 2.7.1):
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
  # 1. Auto-backup existing files
  # 2. Remove old symlinks
  # 3. Create new symlink
}

remove_symlink() {
  # 1. Remove symlink if it exists
  # 2. Warn if target exists but is not a symlink
}
```

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

### Auto-Backup
Existing files are automatically backed up before symlinking:
```
~/.vimrc → ~/.vimrc.backup.YYYYMMDD_HHMMSS
```

### Uninstall Mode
- `--uninstall`: Removes dotfiles, plugins, AND packages (complete removal)

### Idempotent
- Safe to run multiple times
- Checks for existing installations before proceeding
- Won't overwrite or duplicate installations

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
}

uninstall_neovim_setup() {
  echo "=== Neovim Uninstall ==="
  remove_symlink "$HOME/.config/nvim/init.vim"
}

MODE="${1:-install}"
case "$MODE" in
  install) install_neovim_setup ;;
  uninstall) uninstall_neovim_setup ;;
esac
```

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

# Package management helpers
install_pacman_package() {
  local package="$1"
  if pacman -Q "$package" &>/dev/null; then
    echo "✓ $package already installed"
  else
    echo "Installing $package..."
    sudo pacman -S --noconfirm "$package"
    echo "✓ $package installed"
  fi
}

uninstall_pacman_package() {
  local package="$1"
  if pacman -Q "$package" &>/dev/null; then
    echo "Uninstalling $package..."
    sudo pacman -R --noconfirm "$package"
    echo "✓ $package uninstalled"
  fi
}

# Component selection logic
should_install_component() {
  # Same as macos/ubuntu setup.sh
}

install_arch() {
  echo "=== Arch Linux Setup ==="

  # Update package database
  sudo pacman -Sy

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

## Important Notes

- **Internet Required**: For downloading Homebrew, vim-plug, and plugins
- **Safe by Default**: Auto-backup before any changes
- **Idempotent**: Safe to run multiple times
- **Platform Detection**: Automatic, no user input needed
- **Supported Platforms**: macOS and Ubuntu/Debian only
- **Prerequisites**:
  - macOS: Automatically installs Homebrew
  - Ubuntu: Requires `apt-get` (standard)

## Quick Reference

| Task | Command |
|------|---------|
| Install everything | `./bootstrap.sh` or `./bootstrap.sh --install` |
| Install specific components | `./bootstrap.sh --install vim git` |
| Install single component | `./bootstrap.sh vim` |
| Install package-only components | `./bootstrap.sh pyenv pipx` |
| Remove everything | `./bootstrap.sh --uninstall` |
| Remove specific components | `./bootstrap.sh --uninstall bash nvm` |
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
