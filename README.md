# dotx

Cross-platform dotfiles management for macOS and Ubuntu/Debian.

## Quick Install

### One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/wonderchang/dotx/main/install.sh | bash
```

Or with `wget`:
```bash
wget -qO- https://raw.githubusercontent.com/wonderchang/dotx/main/install.sh | bash
```

### Install Specific Components

```bash
curl -fsSL https://raw.githubusercontent.com/wonderchang/dotx/main/install.sh | bash -s -- vim git tmux
```

### Preview Before Installing (Dry-Run)

```bash
curl -fsSL https://raw.githubusercontent.com/wonderchang/dotx/main/install.sh | bash -s -- --dry-run
```

## Manual Installation

```bash
# Clone the repository
git clone https://github.com/wonderchang/dotx.git ~/dotx
cd ~/dotx

# Install everything
./bootstrap.sh

# Or install specific components
./bootstrap.sh vim git tmux bash

# Or preview changes first
./bootstrap.sh --dry-run
```

## What Gets Installed

**Development Tools:**
- **vim** - Vim editor with vim-plug and plugins
- **git** - Git version control with custom configuration
- **tmux** - Terminal multiplexer with powerline theme
- **bash** - Modern bash with bash-git-prompt (custom theme)
- **nvm** - Node Version Manager
- **pyenv** - Python version manager
- **pipx** - Python application installer
- **uv** - Python package and project manager
- **rust** - Rust toolchain via rustup
- **gcloud** - Google Cloud CLI (gcloud, gsutil, bq)
- **aws** - AWS CLI v2

**Configurations:**
- Cross-platform dotfiles (`.vimrc`, `.gitconfig`, `.tmux.conf`, `.bashrc`)
- Platform-specific settings (macOS Homebrew, Ubuntu APT)
- Powerline fonts for tmux
- Custom bash-git-prompt theme

## Customization

**Environment Variables:**
```bash
# Customize installation location (default: ~/dotx)
export DOTFILES_DIR="$HOME/.dotfiles"

# Use a different repository
export DOTFILES_REPO="https://github.com/yourusername/dotx.git"

# Use a different branch
export DOTFILES_BRANCH="develop"

# Then run install.sh
curl -fsSL https://raw.githubusercontent.com/wonderchang/dotx/main/install.sh | bash
```

## Usage

```bash
# Install the basic components
./bootstrap.sh

# Install specific components (optional ones like gcloud only this way)
./bootstrap.sh vim git tmux
./bootstrap.sh gcloud
./bootstrap.sh basic gcloud   # basic set plus gcloud

# Everything, including optional components
./bootstrap.sh all

# Uninstall components
./bootstrap.sh --uninstall vim

# Preview changes (dry-run)
./bootstrap.sh --dry-run --install bash

# Show help
./bootstrap.sh --help
```

## Components

Basic components are installed by a plain `./bootstrap.sh`; optional ones only when named explicitly.

| Component | Tier | Description |
|-----------|------|-------------|
| `vim` | basic | Vim editor with plugins |
| `git` | basic | Git configuration |
| `tmux` | basic | Tmux with powerline theme |
| `bash` | basic | Bash with git prompt |
| `nvm` | basic | Node Version Manager |
| `pyenv` | basic | Python version manager |
| `pipx` | basic | Python app installer |
| `uv` | basic | Python package/project manager |
| `rust` | basic | Rust toolchain (rustup) |
| `gcloud` | optional | Google Cloud CLI |
| `aws` | optional | AWS CLI v2 |
| `basic` | keyword | The basic components (default) |
| `all` | keyword | Basic + optional components |

## Platform Support

- **macOS** - Automatically installs Homebrew if needed
- **Ubuntu/Debian** - Uses APT package manager

## Features

- ✅ **Cross-platform** - Works on macOS and Ubuntu
- ✅ **Selective installation** - Install only what you need
- ✅ **Dry-run mode** - Preview changes before applying
- ✅ **Idempotent** - Safe to run multiple times
- ✅ **Auto-backup** - Existing files are backed up with timestamp
- ✅ **Uninstall support** - Clean removal of all components

## Requirements

- **git** - Required for cloning the repository
- **bash** - Shell scripting (available on all systems)
- **curl** or **wget** - For one-line installation (optional)

## Uninstall

```bash
cd ~/dotx
./bootstrap.sh --uninstall        # the basic components
./bootstrap.sh --uninstall all    # everything, including optional components
```

Or uninstall specific components:
```bash
./bootstrap.sh --uninstall vim git
```

## Troubleshooting

**Powerline fonts not showing in tmux (SSH):**
- Install and configure powerline fonts on your **local machine** (where your terminal emulator runs)
- For iTerm2: Preferences → Profiles → Text → Font → Select a "Powerline" font

**Shell not changed on macOS:**
- Restart your terminal after installation
- Check if bash is in `/etc/shells`: `cat /etc/shells`

**Dry-run to debug:**
```bash
./bootstrap.sh --dry-run
```

## License

WTFPL - Do What The Fuck You Want To Public License

## Credits

- Tmux configuration based on [gpakosz/.tmux](https://github.com/gpakosz/.tmux)
- Inspired by various dotfiles repositories in the community
