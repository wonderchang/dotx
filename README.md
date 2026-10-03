# dotx

One command that turns a fresh macOS or Ubuntu machine into the same shell
environment: the same bash prompt, aliases, vim, tmux and git setup
everywhere, plus the language toolchains and cloud CLIs a workstation needs.
It is reversible (`--uninstall` puts the machine back the way it was),
idempotent (run it again any time) and never asks for more than one password.

```bash
curl -fsSL https://raw.githubusercontent.com/wonderchang/dotx/main/install.sh | bash
```

## Which command for which machine

| You are setting up… | Run | You get |
|---|---|---|
| **Your own workstation** (Mac or Ubuntu desktop) | `./bootstrap.sh` | the shell experience + Node, Python and Rust toolchains, personal Claude Code instructions, powerline fonts, iTerm2 profile on macOS, GitHub over SSH |
| **A server, a container, WSL, a colleague's box** | `./bootstrap.sh minimal` | the shell experience only: vim, git, tmux, htop, bash. Plain tmux theme, no fonts, no toolchains, no signing key, clones stay on HTTPS |
| **A workstation that also does cloud / VM / container work** | `./bootstrap.sh all` or `./bootstrap.sh basic gcloud docker` | everything above plus gcloud, aws, lima and docker |
| **Just one tool** | `./bootstrap.sh tmux` | that component only, in whatever profile the machine already has |
| **Checking first** | `./bootstrap.sh --dry-run …` | the full plan, nothing changed |
| **Leaving** | `./bootstrap.sh --uninstall` | your original files back, only the packages dotx installed removed |

The machine remembers which tier it was set up with. A plain `./bootstrap.sh`
on a server set up with `minimal` stays minimal; only an explicit `basic` or
`all` turns it into a workstation.

## Install

**One line** (clones into `~/dotx`, then runs `bootstrap.sh` with any
arguments you pass):

```bash
curl -fsSL https://raw.githubusercontent.com/wonderchang/dotx/main/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/wonderchang/dotx/main/install.sh | bash -s -- minimal
curl -fsSL https://raw.githubusercontent.com/wonderchang/dotx/main/install.sh | bash -s -- --dry-run all
```

`wget -qO-` works in place of `curl -fsSL`. `DOTFILES_DIR`, `DOTFILES_REPO`
and `DOTFILES_BRANCH` change where it clones from and to.

**By hand:**

```bash
git clone https://github.com/wonderchang/dotx.git ~/dotx
cd ~/dotx
./bootstrap.sh --dry-run   # look first
./bootstrap.sh             # then do it
```

Requirements: `git` and `bash`. On macOS, Homebrew is installed if missing
(and so is a modern bash, which becomes your login shell; open a new terminal
afterwards). On Ubuntu, `curl` and `git` come from APT first. A password is
asked once at the start of a run, only when a step needs `sudo`.

## The three tiers

Every component is in exactly one tier. A tier is a keyword you can pass
instead of component names.

### `minimal`: the shell experience

What makes any box feel like yours, with nothing that assumes it *is* yours.

| Component | Both platforms | Profile `minimal` leaves out |
|---|---|---|
| `bash` | `~/.bashrc` with bash-git-prompt (custom theme), safe `rm` (moves to trash), history tuning, `~/.bashrc.local` per platform; Homebrew bash as login shell on macOS | |
| `vim` | `~/.vimrc`, vim-plug, plugins installed non-interactively (airline, JS/TS/JSX, GraphQL, Terraform, Rust, JSON) | |
| `tmux` | `~/.tmux.conf` (gpakosz-based, prefix `C-a`, mouse toggle) | powerline theme, powerline fonts, iTerm2 font and Smyck profile |
| `git` | `~/.gitconfig`: aliases (`st`, `co`, `gr` …), vimdiff, LFS, identity | `~/.gitconfig.local`: GitHub `https://` → SSH rewrite; commit signing and `gh` credential helper on macOS |
| `htop` | the package | |

### `basic` (default): a workstation

`minimal` in the full profile, plus the toolchains and personal AI-assistant
instructions. Everything installs into your home directory and is wired into
`.bashrc`.

| Component | Installs |
|---|---|
| `nvm` | Node Version Manager in `~/.nvm` |
| `pyenv` | pyenv in `~/.pyenv`, with the build libraries from pyenv's suggested environment on Ubuntu |
| `pipx` | Python app installer (Homebrew / APT) |
| `uv` | Python package and project manager in `~/.local/bin` |
| `rust` | rustup toolchain in `~/.cargo`, `build-essential` on Ubuntu |
| `claude` | personal Claude Code instructions: `~/.claude/CLAUDE.md` (language, safety) and `~/.claude/rules/` (thinking, output), loaded in every project, plus a `PreToolUse` hook that turns destructive commands (force push, `git reset --hard`, `rm -rf`, `DROP TABLE`, `terraform destroy` …) into a permission prompt even in auto mode. The hook is registered in `settings.json` by merging one entry; the rest of `~/.claude` and the `claude` binary are not touched |

### Optional: only when named

Never installed by a bare `./bootstrap.sh`; `all` includes them.

| Component | macOS | Ubuntu | Why this way |
|---|---|---|---|
| `gcloud` | Homebrew cask `gcloud-cli` (gcloud, gsutil, bq) | Google's APT repo, `google-cloud-cli` | the tarball on Apple Silicon has no Python and its installer puts python.org Python system-wide with sudo |
| `aws` | Homebrew `awscli` (v2) | official AWS zip installer into `~/.local/aws-cli`, no sudo | Ubuntu's own `awscli` package is still v1 on 22.04 |
| `lima` | Homebrew `lima` (Virtualization.framework) | latest GitHub release tarball into `~/.local/lima`, QEMU from APT | no Lima package in Ubuntu; the version comes from the release redirect, no API call |
| `docker` | colima (rootful dockerd in a Lima VM) + Homebrew docker CLI, compose, buildx, credential helper | Docker's APT repo: Engine, CLI, containerd, compose and buildx plugins; your user joins the `docker` group | Docker Desktop needs sudo at install, a click-through first launch and a licence for larger companies; Lima's docker template is rootless |

Bash completion for all four is registered by `.bashrc`. Your credentials and
data are never removed: `~/.config/gcloud` (only the virtualenv goes),
`~/.aws`, `~/.lima` (the uninstall warns when VMs exist), Docker images and
volumes, and a colima profile or `~/.docker/config.json` that existed before
dotx. On macOS a colima VM is created only when none exists and is not started
at login (the run prints how); size it with `DOTX_COLIMA_CPU/MEMORY/DISK`.

## What a run promises

- **Idempotent.** A second run is a no-op and the test suite checks that it
  is: symlinks already in place, packages already present, vim plugins whose
  directories exist and powerline fonts already installed are all skipped,
  and nothing is re-cloned.
- **Reversible.** `--uninstall` restores the file a symlink replaced (every
  replaced file is backed up as `<name>.backup.<timestamp>` first, so the
  stock `~/.bashrc` comes back) and removes only the packages dotx installed;
  see the next section. On a fresh Ubuntu image the installed-package set
  after `--uninstall all` is identical to the one before dotx.
- **Non-interactive.** Third-party installers (Homebrew, rustup, nvm, pyenv,
  vim-plug, apt) run without prompts. The only prompt is the single `sudo`
  password at the start, and only when a step needs it.
- **Previewable.** `--dry-run` prints every step with `[DRY-RUN]` and changes
  nothing.
- **Works without your SSH key.** Clones made during a run always use HTTPS,
  even though the full-profile gitconfig rewrites GitHub URLs to SSH.

## How uninstall knows what to remove

dotx keeps a small ledger under `~/.local/state/dotx/` (`apt/` on Ubuntu,
`brew/` on macOS): one file per component listing what that component needs,
and one `_installed` file listing what dotx itself put on the machine. Three
rules follow from it:

- **Pre-existing packages are never touched.** A `tmux` or `htop` that was
  there before dotx is left alone by `--uninstall tmux`, because it is not in
  `_installed`.
- **Shared dependencies are reference-counted.** `build-essential` is needed
  by both `rust` and `pyenv` (it is not a base prerequisite; a `minimal`
  server has no compiler until it runs `./bootstrap.sh rust`). `--uninstall
  rust` keeps it while pyenv is still there; uninstalling the last user
  removes it. Same for the `lima` formula while colima is installed.
- **Whole APT transactions are recorded.** Every dependency `apt-get install`
  pulls in is recorded with the component that caused it and removed
  explicitly on uninstall, after an `apt-get -s` simulation that keeps (and
  reassigns) anything something else still depends on. Leaving this to
  `autoremove` is not enough: apt 3.x keeps auto-installed packages that an
  installed package merely *Suggests*, so gcc and make would outlive
  `build-essential`.

`tests/unit-apt-common.sh` exercises these rules against a fake package
database without a VM.

## Command reference

```bash
./bootstrap.sh                     # the tier this machine was set up with (basic on a new one)
./bootstrap.sh minimal             # shell experience only, minimal profile
./bootstrap.sh basic               # workstation, full profile
./bootstrap.sh all                 # workstation + gcloud aws lima docker
./bootstrap.sh basic gcloud        # workstation + gcloud
./bootstrap.sh vim git tmux        # just these, current profile kept
./bootstrap.sh --dry-run all       # preview any of the above

./bootstrap.sh --uninstall         # the tier this machine was set up with
./bootstrap.sh --uninstall all     # everything, optional components included
./bootstrap.sh --uninstall docker  # one component

./bootstrap.sh --help
```

Switching a machine between tiers is just running the other keyword:
`minimal` after `basic` removes nothing but turns the stylish parts off (plain
tmux theme, no `~/.gitconfig.local`); `basic` after `minimal` adds the
toolchains and turns them back on.

## Customization

| Variable | Effect |
|---|---|
| `DOTFILES_DIR`, `DOTFILES_REPO`, `DOTFILES_BRANCH` | where `install.sh` clones from and to (default `~/dotx`, this repo, `main`) |
| `DOTX_COLIMA_CPU`, `DOTX_COLIMA_MEMORY`, `DOTX_COLIMA_DISK` | size of the colima VM the `docker` component creates on macOS (default 4 / 8 / 100) |

Machine-specific shell settings belong in `~/.bashrc.local` (linked per
platform, sourced by `.bashrc`); machine-specific git settings in
`~/.gitconfig.local`.

## Layout

```
bootstrap.sh              entry point: mode, dry-run, tier, profile
install.sh                curl | bash wrapper around it
common/<component>/       cross-platform config + setup.sh (install/uninstall)
platform/macos/           Homebrew, shell switch, iTerm2, docker (colima)
platform/ubuntu/          APT, gcloud/aws/lima/docker installers
utils/                    platform detection, tiers + profile, sudo-once, symlinks
tests/                    end-to-end run in a Lima Ubuntu VM, APT state unit test
```

`tests/run-in-lima.sh [--fresh] [--profile=full|minimal]` runs the whole
cycle in a throwaway Ubuntu VM: snapshot the installed packages, `./bootstrap.sh
all` (or `minimal`), verify every symlink, package, completion and a clean
login shell, re-install (must be a no-op), `--uninstall all`, then check that
the home directory and the package set are back to the snapshot. Both
profiles pass on fresh Ubuntu 26.04 images; see `tests/README.md`.

## Troubleshooting

- **Powerline symbols look broken over SSH.** The font has to be on the
  machine where the terminal runs, not on the server. Either install the
  fonts locally (`./bootstrap.sh tmux` on the Mac does it) or set up the
  server with `minimal`, which uses a plain theme.
- **macOS shell did not change.** Open a new terminal; the login shell is
  changed with `dscl`, which takes effect on the next login. `cat /etc/shells`
  should list the Homebrew bash.
- **Something unexpected would change.** `./bootstrap.sh --dry-run` shows
  every step before it happens.
- **macOS: `brew doctor`. Ubuntu: `sudo apt-get update`** when a package
  install fails.

## License

WTFPL - Do What The Fuck You Want To Public License

## Credits

- Tmux configuration based on [gpakosz/.tmux](https://github.com/gpakosz/.tmux)
- Inspired by various dotfiles repositories in the community
