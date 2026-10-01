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

**Basic components (default):** `vim`, `git`, `tmux`, `bash`, `nvm`, `pyenv`, `pipx`, `uv`, `rust`
**Optional components (only when named):** `gcloud`, `aws`
**Keywords:** `basic` (the default set), `all` (basic + optional)

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
│   ├── uv/                         # uv installer
│   └── rust/                       # Rust installer (rustup)
├── platform/
│   ├── macos/                      # macOS setup + Homebrew + iTerm2 font
│   └── ubuntu/                     # Ubuntu setup + APT + gcloud APT repo + aws installer
└── utils/                          # Shared utilities
    ├── detect.sh                   # Platform detection
    ├── shell.sh                    # Shell switching
    ├── components.sh               # Basic/optional component tiers + selection
    ├── sudo.sh                     # One-time password prompt + sudo keepalive
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

Two tiers, defined in `utils/components.sh` (`BASIC_COMPONENTS`, `OPTIONAL_COMPONENTS`):

- **No components** or **`basic`** → the basic set
- **`all`** → basic + optional (everything dotx knows)
- **Specific components** → exactly those (`basic gcloud` = basic set plus gcloud)

The same rules apply to `--uninstall`: a plain `--uninstall` removes the basic set, `--uninstall all` also removes optional components. `should_install_component()` in `utils/components.sh` implements this and is shared by both platform setup scripts.

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
- Links iTerm2 Dynamic Profiles from `platform/macos/iterm2/*.json` (e.g. Smyck color scheme, inherits from Default) into `~/Library/Application Support/iTerm2/DynamicProfiles/`; hot-reloaded, works while iTerm2 is running
- Sets the Smyck dynamic profile as iTerm2's default profile via `defaults`; skipped while iTerm2 is running (it reads the default only at launch), previous default restored on uninstall
- `gcloud` is the Homebrew cask `gcloud-cli` (`install_brew_cask()`), which pulls in `python@3.14`, builds `~/.config/gcloud/virtenv` on it and links gcloud/gsutil/bq into Homebrew's bin (the cask keeps a pre-existing virtenv untouched, so `ensure_gcloud_virtenv()` rebuilds one that is not on Homebrew Python); uninstall uses `brew uninstall --cask --zap` (a plain uninstall leaves `share/google-cloud-sdk` behind) and removes the virtenv, but keeps the rest of `~/.config/gcloud` (credentials). Not the tarball: on Apple Silicon the tarball has no bundled Python and `install.sh --install-python` installs python.org Python system-wide with sudo
- `aws` is the Homebrew formula `awscli` (v2, `aws` + `aws_completer` in Homebrew's bin); `~/.aws` is never touched. Completion for both platforms is registered in `common/bash/.bashrc` via `complete -C aws_completer aws`

**Ubuntu specifics:**
- Runs `apt-get update` and installs base prerequisites `curl` and `git` first (via `apt.sh`); the `git` component only manages `.gitconfig` and never removes the git package
- Uses `install_apt_package()` helper
- `aws` uses the official AWS CLI v2 zip installer (`aws.sh`) into `~/.local/aws-cli` with symlinks in `~/.local/bin`, no sudo except `apt-get install unzip`; Ubuntu's APT `awscli` is v1 on 22.04. `~/.aws` is never touched
- `gcloud` comes from Google's APT repo (`gcloud.sh`): signing key in `/usr/share/keyrings/cloud.google.gpg`, source list in `/etc/apt/sources.list.d/google-cloud-sdk.list`, package `google-cloud-cli`; the APT build disables `gcloud components`, add-ons are `google-cloud-cli-*` packages and are all removed on uninstall together with the key and source list

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
- vim-plug, bash-git-prompt, powerline fonts, nvm, pyenv, uv, rust

**Platform-specific configs:**
- `~/.bashrc.local` → `platform/{macos,ubuntu}/.bashrc.{macos,ubuntu}`

**macOS packages (Homebrew):** bash, tmux, pipx, gcloud-cli (cask), awscli

**Ubuntu packages (APT):** vim, git, tmux, pipx, google-cloud-cli (from Google's APT repo), unzip (for the aws installer)

**Ubuntu user-level installs:** aws → `~/.local/aws-cli` with `aws`/`aws_completer` in `~/.local/bin` (official AWS installer, no sudo)

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
- Changes the login shell with `sudo dscl ... UserShell` (not `chsh`: macOS `chsh` asks for the user's password even under sudo), so it reuses the password asked once at the start of the run
- **Requires terminal restart** for changes to take effect

## Adding New Components

### With Configuration Files

1. Create `common/{tool}/setup.sh` with `install_*()` and `uninstall_*()` functions
2. Add dry-run checks for all operations
3. Update `platform/{macos,ubuntu}/setup.sh` with conditional installation
4. Add the name to `BASIC_COMPONENTS` or `OPTIONAL_COMPONENTS` in `utils/components.sh` and to the help text in `bootstrap.sh`
5. Update this file's component list

### Package-Only (No Config)

1. Add conditional block in `platform/{macos,ubuntu}/setup.sh`
2. Add the name to `BASIC_COMPONENTS` or `OPTIONAL_COMPONENTS` in `utils/components.sh` and to the help text in `bootstrap.sh`
3. Update this file's component list

## Development Guidelines

- **Always add dry-run support** to new operations
- **Never block on a prompt** - run third-party installers non-interactively (`NONINTERACTIVE=1` for the Homebrew installer, `HOMEBREW_NO_ASK=1` for `brew install`, `-y` for rustup/apt, `vim -es` for PlugInstall); the only prompt allowed is the single password request at the start of a run (`request_sudo` in `utils/sudo.sh`, asked only when a later step needs sudo; run anything that needs root through `sudo` so the cached credential is reused; `HOMEBREW_NO_SUDO=1` is exported on macOS because every `brew` command otherwise runs `sudo --reset-timestamp` and wipes that cache)
- **Use `${DRY_RUN:-false}` pattern** for consistency
- **Quiet curl output** - `curl -fsSL url | bash` for installer scripts (no transfer table, HTTP errors fail instead of piping an error page into bash); `curl -fSL --progress-bar -o file url` when downloading an actual file
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
- Restart terminal after the shell change
