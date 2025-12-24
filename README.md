# Universal Dotfiles

A cross-platform dotfiles management system for macOS and Ubuntu.

## Features

- 🚀 **Simple**: One command handles install/upgrade/uninstall
- 🔒 **Safe**: Auto-backup before changes
- 📦 **Modular**: Install only what you need
- 🎯 **Cross-platform**: macOS and Ubuntu
- ⚡ **Consistent**: Same versions across all machines

## Quick Start

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/universal-dotfile.git ~/.dotfiles
cd ~/.dotfiles

# Install everything
make install

# Or install individual components
make vim
make bash
make git
make tmux
```

## Components

- **vim**: Text editor with vim-plug and plugins
- **bash**: Shell configuration with git-prompt
- **git**: Version control configuration
- **tmux**: Terminal multiplexer configuration

## Usage

### Using Makefile (Recommended)

```bash
# Install all components
make install
make  # Same as 'make install'

# Upgrade all components
make upgrade

# Uninstall configurations (keep packages)
make uninstall

# Uninstall configurations + packages
make uninstall-purge

# Show help
make help
```

### Individual Components

```bash
# Install
make vim
make bash
make git
make tmux

# Upgrade
make vim-upgrade
make bash-upgrade
make git-upgrade
make tmux-upgrade

# Uninstall
make vim-uninstall
make bash-uninstall
make git-uninstall
make tmux-uninstall
```

### Using Scripts Directly

```bash
# Install (default mode)
bash scripts/components/vim.sh
bash scripts/components/vim.sh --install

# Upgrade
bash scripts/components/vim.sh --upgrade

# Uninstall (keep package)
bash scripts/components/vim.sh --uninstall

# Uninstall (remove package too)
bash scripts/components/vim.sh --uninstall --purge
```

## Architecture

```
universal-dotfile/
├── Makefile                    # Simple orchestrator
├── scripts/
│   ├── components/
│   │   ├── bash.sh             # Bash component manager
│   │   ├── git.sh              # Git component manager
│   │   ├── tmux.sh             # Tmux component manager
│   │   └── vim.sh              # Vim component manager
│   └── utils/
│       ├── detect.sh           # Platform detection utilities
│       └── symlink.sh          # Symlink management utilities
├── common/
│   ├── .vimrc                  # Vim configuration
│   ├── .gitconfig              # Git configuration
│   ├── .tmux.conf              # Tmux configuration
│   ├── .tmux.conf.local        # Tmux local overrides
│   └── bash/
│       └── .bashrc.common      # Common bash configuration
└── platform/
    ├── macos/
    │   ├── .bash_profile       # macOS bash entry point
    │   └── .bashrc.macos       # macOS-specific bash config
    └── ubuntu/
        ├── .bashrc             # Ubuntu bash entry point
        └── .bashrc.ubuntu      # Ubuntu-specific bash config
```

### Design Principles

1. **Modular with Shared Utilities**: Components use common utility scripts
   - Platform detection shared via `scripts/utils/detect.sh`
   - Symlink management shared via `scripts/utils/symlink.sh`
   - Component scripts focus on tool-specific logic

2. **Three-Mode Interface**: Consistent command interface
   - `--install`: Install package + configuration
   - `--upgrade`: Upgrade package + plugins
   - `--uninstall`: Remove configuration only
   - `--uninstall --purge`: Remove configuration + package

3. **Makefile as Thin Wrapper**: Simple orchestration
   - `make install` → runs all component install scripts
   - `make upgrade` → runs all component upgrade scripts
   - No complex logic, just delegation

## What Gets Installed

### Bash
- **Package**: Modern bash 5.x on macOS (via Homebrew), system bash on Ubuntu
- **bash-git-prompt**: Git prompt enhancement (v2.7.1)
- **Configuration**: Platform-specific bash profiles + common config
- **Symlinks**:
  - macOS: `~/.bash_profile`, `~/.bashrc.macos`, `~/.bashrc.common`
  - Ubuntu: `~/.bashrc`, `~/.bashrc.ubuntu`, `~/.bashrc.common`

### Git
- **Package**: Latest git via Homebrew (macOS) or apt (Ubuntu)
- **Configuration**: Aliases, editor settings, colors
- **Symlinks**: `~/.gitconfig`

### Tmux
- **Package**: Latest tmux via Homebrew (macOS) or apt (Ubuntu)
- **Configuration**: Custom keybindings, mouse support, status bar
- **Symlinks**: `~/.tmux.conf`, `~/.tmux.conf.local`

### Vim
- **Package**: Specific version (9.1) or latest
  - macOS: via Homebrew
  - Ubuntu: via apt (latest) or compiled from source (version specified)
- **vim-plug**: Plugin manager (v0.14.0)
- **Configuration**: Custom .vimrc with plugins
- **Symlinks**: `~/.vimrc`

## Version Management

Set consistent versions across platforms by editing `scripts/components/*.sh`:

```bash
# scripts/components/vim.sh
VERSION_VIM="9.1"  # Same version on macOS and Ubuntu

# scripts/components/bash.sh
VERSION_BASH=""    # Empty = latest (5.x on macOS, system on Ubuntu)

# scripts/components/git.sh
VERSION_GIT=""     # Empty = latest

# scripts/components/tmux.sh
VERSION_TMUX=""    # Empty = latest
```

**Vim Version Strategy**:
- **macOS**: Uses Homebrew formula `vim@9.1`
- **Ubuntu**: Compiles from source (clones vim repo, checks out v9.1, builds)
- **Result**: Same vim version on both platforms for consistent behavior

## Safety Features

### Auto-Backup
Existing files are automatically backed up before symlinking:
```
~/.vimrc → ~/.vimrc.backup.YYYYMMDD_HHMMSS
```

### Uninstall Modes
- **Default** (`--uninstall`): Removes configs, keeps packages
- **Purge** (`--uninstall --purge`): Removes configs AND packages

## Platform Support

| Platform | Bash | Git | Tmux | Vim |
|----------|------|-----|------|-----|
| macOS | Homebrew bash 5.x | Homebrew | Homebrew | Homebrew |
| Ubuntu | System bash | apt | apt | apt / source |

## Configuration Cascade

### macOS
```
~/.bash_profile (login shell)
  → ~/.bashrc.common (shared config)
  → ~/.bashrc.macos (macOS-specific)
  → ~/.bashrc.local (user overrides, optional)
```

### Ubuntu
```
~/.bashrc (interactive shell)
  → ~/.bashrc.common (shared config)
  → ~/.bashrc.ubuntu (Ubuntu-specific)
  → ~/.bashrc.local (user overrides, optional)
```

## Customization

### Adding Local Overrides

Create `~/.bashrc.local` for user-specific customizations that won't be tracked:

```bash
# ~/.bashrc.local
export MY_CUSTOM_VAR="value"
alias myalias="command"
```

### Editing Configurations

- **Vim**: Edit `common/.vimrc`
- **Git**: Edit `common/.gitconfig`, then `git config --global` for identity
- **Tmux**: Edit `common/.tmux.conf` or `common/.tmux.conf.local`
- **Bash**: Edit `common/bash/.bashrc.common` or platform-specific files

## Post-Installation

### Git Identity

After installing git, configure your identity:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### macOS Bash Shell

On macOS, after bash installation, switch to Homebrew bash:

```bash
chsh -s /opt/homebrew/bin/bash
```

Then restart your terminal.

## License

MIT
