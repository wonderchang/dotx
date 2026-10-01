# dotx Principles

dotx is not just a set of dotfiles. It is **the single entry point for managing my development environment**.
Any change to the environment, whether adding a tool, adjusting a config, removing something unused, or troubleshooting a problem, starts here and is applied with the same command.

This document describes what dotx aims to achieve and the principles every change must follow to get there.
For implementation details (directory layout, command usage, adding components), see [README.md](README.md) and [CLAUDE.md](CLAUDE.md).

---

## Five Goals

### 1. One-command install

A fresh machine gets a complete development environment with a single command.

```bash
./bootstrap.sh            # install everything
./bootstrap.sh vim tmux   # install specific components
```

- It starts with nothing but what the system ships with. On a fresh Mac that means bash 3.2 and no Homebrew on PATH, and it must still run to completion.
- Nothing needs to be prepared by hand beforehand. Prerequisites such as Homebrew or package index updates are handled by dotx itself.
- The run never stops to ask questions. If administrator rights are needed, the password is asked **once, at the start**, and reused by every later step.
- Steps that genuinely cannot be automated (for example, changing iTerm2 settings while it is running) must print the reason and the manual steps. They are never skipped silently.

### 2. One-command uninstall

Whatever gets installed can be removed completely with a single command.

```bash
./bootstrap.sh --uninstall              # uninstall everything
./bootstrap.sh --uninstall tmux         # uninstall specific components
```

- Uninstall is the reverse of install: every symlink, package, and setting created during install can be taken back.
- Original settings that dotx overrides are backed up on install and restored on uninstall (for example, files replaced by symlinks, or iTerm2's original font and default profile).
- Uninstall must not stop halfway and leave a partial state. If one step fails, unrelated components should still be uninstalled.

### 3. Explicit dependencies, independent uninstall and reinstall

Each component is a unit that can be installed, uninstalled, and reinstalled on its own.

- Components without dependencies on each other must not affect each other. Uninstalling `rust` should not touch `tmux`, and reinstalling `vim` should not require running the whole setup.
- Dependencies between components must be **stated explicitly**, not left to whatever happens to come first:
  - On install, dependencies go first. For example, Homebrew comes before any brew package, and powerline fonts come before the iTerm2 font setting.
  - On uninstall, the order is reversed and dependencies are removed last. For example, git goes last because the tmux uninstall needs it to remove the fonts, and Homebrew bash goes last because the remaining steps run with `bash`.
- "Uninstall, then install" must always return to the same state. It is the most basic tool for troubleshooting the environment.

### 4. Every run is idempotent

`./bootstrap.sh` is not a script that runs once on a new machine. It is an **apply that can be re-run at any time**.

- Running the same command once or ten times gives exactly the same result. Anything already in the correct state is reported as "already" and is not redone, rewritten, or backed up again.
- Day-to-day changes are made by editing the config in the repo and re-running bootstrap to apply them. There is no need to uninstall first or to remember where the last run left off.
- Every operation that changes the system checks the current state first and acts only when needed.
- Every operation supports `--dry-run`: preview what would change, then run it for real. A dry-run must not change anything, and must not stop because an earlier step was only previewed.

### 5. The single window for environment changes

Everything related to the environment starts from dotx.

- **Adding or adjusting a tool** → add a component or change a config in dotx and apply it with bootstrap. Don't change the system by hand.
- **Something is wrong with the environment** → start troubleshooting from dotx: use `--dry-run` to see whether the state has drifted, then uninstall and reinstall to bring components back to a known state.
- **Changes made by hand on the system** (for example, tweaks in iTerm2 Settings, or lines an installer appends to `.bash_profile`) are either brought into dotx or reverted. The actual environment and the repo must not stay out of sync.
- The repo is the source of truth for the environment: reading it tells you what this machine has installed and how it is configured, and the same environment can be rebuilt on another machine.

---

## Implementation Principles

Every change follows these principles in order to meet the five goals above.

| Principle | Practice |
|---|---|
| **Single entry point** | Everything goes through `bootstrap.sh`. Platform differences live in `platform/{macos,ubuntu}/`, and cross-platform configs live in `common/`. |
| **Install and uninstall in pairs** | Every `install_*` has a matching `uninstall_*`. New features write and test both sides together. |
| **Check before acting** | Check the current state before acting, and skip if it is already correct. Symlinks always go through `utils/symlink.sh`, which is idempotent. |
| **Back up before overriding** | Back up before replacing an existing file or setting, and restore it on uninstall, but only while the state is still what dotx set, so later changes made by the user are not overwritten. |
| **Dry-run everywhere** | Every operation that changes the system checks `${DRY_RUN:-false}` and prints `[DRY-RUN] Would ...`. |
| **Fail loudly** | Scripts use `set -eu`. Steps that cannot be automated print the reason and the manual steps. Never fail silently or pretend to succeed. |
| **Pure bash, minimal dependencies** | Use only bash and tools the system ships with. No Python, Makefile, or other runtimes. Must run on bash 3.2. |
| **Consistent across platforms** | macOS and Ubuntu offer the same components and behavior; they differ only in the package manager and platform-specific settings. |
| **Predictable changes** | Don't change anything outside what dotx manages. When external state must change (such as application settings), keep it to a clearly defined scope and make it reversible. |

---

## Checklist

When adding or changing a component, confirm that all of the following hold:

- [ ] `./bootstrap.sh <component>` installs successfully on a fresh environment
- [ ] Running it again reports every step as already done, with no changes
- [ ] `./bootstrap.sh --uninstall <component>` removes it completely and restores overridden settings
- [ ] Uninstalling and then reinstalling gives the same result as the first install
- [ ] `--dry-run` runs to completion for both install and uninstall, without changing anything
- [ ] Dependencies on other components are documented, and install and uninstall order are correct
- [ ] Both macOS and Ubuntu are handled (or the component is explicitly marked as single-platform)
- [ ] It runs under bash 3.2
