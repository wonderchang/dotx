# CLAUDE.md

This file provides guidance to Claude Code when working with this dotfiles repository.

## Repository Overview

Cross-platform dotfiles management tool for **macOS** and **Ubuntu/Debian** using a bootstrap-based architecture. Automates development environment setup with consistent configurations across platforms.

## Architecture

**Bootstrap pattern with platform delegation:**
```
./bootstrap.sh → platform/{macos,ubuntu}/setup.sh → {packages, configs, plugins}
```

**Design principles:**
- Single entry point via `bootstrap.sh`
- Platform-specific setup in `platform/{macos,ubuntu}/`
- Cross-platform configs in `common/`
- Shared utilities in `utils/`
- Two modes: `--install` and `--uninstall`
- Dry-run support via `--dry-run` flag
- Pure bash (no Makefile)

## Core Commands

```bash
# Install all components
./bootstrap.sh

# Install specific components
./bootstrap.sh vim git tmux

# Uninstall
./bootstrap.sh --uninstall [components]

# Dry-run (preview changes)
./bootstrap.sh --dry-run [--install|--uninstall] [components]

# Show help
./bootstrap.sh --help
```

**Available components:** `vim`, `git`, `tmux`, `bash`, `nvm`, `pyenv`, `pipx`, `uv`, `rust`, `all`

## Directory Structure

```
dotx/
├── bootstrap.sh                    # Main entry point
├── common/                         # Cross-platform configs
│   ├── bash/                       # Bash config + bash-git-prompt
│   ├── git/                        # Git config
│   ├── vim/                        # Vim config + vim-plug
│   ├── tmux/                       # Tmux config + powerline fonts
│   ├── nvm/                        # NVM installer
│   ├── pyenv/                      # pyenv installer
│   ├── pipx/                       # pipx installer
│   ├── uv/                         # uv installer
│   └── rust/                       # Rust installer (rustup)
├── platform/
│   ├── macos/                      # macOS setup + Homebrew + iTerm2 font
│   └── ubuntu/                     # Ubuntu setup + APT
└── utils/                          # Shared utilities
    ├── detect.sh                   # Platform detection
    ├── shell.sh                    # Shell switching
    └── symlink.sh                  # Symlink management
```

## How It Works

### Bootstrap Flow

1. Parse arguments (mode, dry-run flag, components)
2. Detect platform (macOS or Ubuntu)
3. Export `DRY_RUN` environment variable
4. Delegate to `platform/{macos,ubuntu}/setup.sh` with components
5. For each component:
   - Install package (inline, platform-specific)
   - Setup configuration (from `common/`)

### Component Selection

- **No components** → Install all
- **`all` specified** → Install all
- **Specific components** → Install only those

Implementation uses `should_install_component()` function in platform setup scripts.

### Platform Setup

**Inline package management pattern:**
```bash
if should_install_component "vim"; then
  install_package "vim"              # Platform-specific
  bash common/vim/setup.sh install   # Cross-platform config
fi
```

**macOS specifics:**
- Installs Homebrew first (via `homebrew.sh`)
- Modern bash via Homebrew (macOS ships with old bash 3.2)
- Automatic shell switching to bash on macOS
- Uses `install_brew_package()` helper
- Sets iTerm2 default profile font to Source Code Pro for Powerline (via `iterm2.sh`, part of `tmux`); skipped while iTerm2 is running or if a Powerline/Nerd font is already set, restored on uninstall

**Ubuntu specifics:**
- Runs `apt-get update` first (via `apt.sh`)
- Uses `install_apt_package()` helper

### Dry-Run Support

All operations check `${DRY_RUN:-false}` before executing:
```bash
if [ "${DRY_RUN:-false}" = "true" ]; then
  echo "[DRY-RUN] Would install package"
else
  install package
fi
```

### Symlink Management

`utils/symlink.sh` provides:
- `create_symlink()` - Creates symlinks with auto-backup
- `remove_symlink()` - Removes symlinks safely
- **Idempotent** - Checks if symlink already correct before doing work
- **Dry-run aware** - Previews changes without applying

## What Gets Installed

**Cross-platform configs (symlinked):**
- `~/.vimrc`, `~/.gitconfig`, `~/.tmux.conf`, `~/.bashrc`
- vim-plug, bash-git-prompt, powerline fonts, nvm, pyenv, pipx, uv, rust

**Platform-specific configs:**
- `~/.bashrc.local` → `platform/{macos,ubuntu}/.bashrc.{macos,ubuntu}`

**macOS packages (Homebrew):** bash, tmux

**Ubuntu packages (APT):** vim, git, tmux

## Important Notes

### Tmux Configuration

**Dual-purpose file format:**
- `.tmux.conf` embeds shell functions as comments (lines 134+)
- Line 131: `run 'cut -c3- ~/.tmux.conf | bash -s apply_configuration'`
- Extracts commented code (removes `# ` prefix) and executes as bash script
- **Must use `bash`, not `sh`** - Ubuntu's `/bin/sh` is dash (POSIX), not bash
- Functions use bash-specific syntax (`${var:-default}`, etc.)

**Embedded functions:**
- `apply_theme()` - Applies powerline theme from `.tmux.conf.local`
- `battery()` - Battery status (macOS: `pmset`, Linux: `/sys/class/power_supply/`)
- `toggle_mouse()`, `maximize_pane()`, etc.

**Powerline fonts:**
- Installed on both platforms by `common/tmux/setup.sh`
- For SSH (iTerm2 → Ubuntu): Fonts must be on **client** (macOS), not server
- Terminal must be configured to use a powerline font

### Shell Switching (macOS)

- Installs modern bash via Homebrew (5.x vs system 3.2)
- Automatically switches from zsh to Homebrew bash
- Adds bash to `/etc/shells` if needed
- Requires password for `chsh` command
- **Requires terminal restart** for changes to take effect

## Adding New Components

### With Configuration Files

1. Create `common/{tool}/setup.sh` with `install_*()` and `uninstall_*()` functions
2. Add dry-run checks for all operations
3. Update `platform/{macos,ubuntu}/setup.sh` with conditional installation
4. Update `bootstrap.sh` to accept component name
5. Update this file's component list

### Package-Only (No Config)

1. Add conditional block in `platform/{macos,ubuntu}/setup.sh`
2. Update `bootstrap.sh` to accept component name
3. Update this file's component list

## Development Guidelines

- **Always add dry-run support** to new operations
- **Use `${DRY_RUN:-false}` pattern** for consistency
- **Test both dry-run and actual execution** paths
- **Make scripts idempotent** - safe to run multiple times
- **Use absolute paths** when sourcing utilities
- **Handle errors gracefully** with meaningful messages
- **Follow existing patterns** in platform setup scripts

## Troubleshooting

**Symlink issues:** Run with `--dry-run` first to preview changes

**Package installation fails:**
- macOS: `brew doctor`
- Ubuntu: `sudo apt-get update`

**Tmux powerline not working:**
- Check if fonts installed: `fc-list | grep -i powerline`
- For SSH: Configure terminal on **client** machine
- Verify bash (not sh) in `.tmux.conf` line 131

**Shell switching fails (macOS):**
- Ensure Homebrew bash installed first
- Check `/etc/shells` contains Homebrew bash path
- Restart terminal after `chsh`
