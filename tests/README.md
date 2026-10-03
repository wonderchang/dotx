# tests

End-to-end verification of the Ubuntu side in a throwaway Lima VM.

```bash
tests/run-in-lima.sh                    # reuse (or create) the dotx-ubuntu VM, full profile
tests/run-in-lima.sh --fresh            # recreate the VM first: the strict, fresh-machine run
tests/run-in-lima.sh --profile=minimal  # test `./bootstrap.sh minimal` instead of `all`
tests/run-in-lima.sh --stop             # stop the VM afterwards
LIMA_INSTANCE=dotx-x tests/run-in-lima.sh   # use another VM (two sessions testing at once)
```

It syncs the working tree into the VM, snapshots the installed packages and
`~/.bashrc`, then runs `./bootstrap.sh all` (or `minimal`), the checks
below, a second install (must be a no-op), `./bootstrap.sh --uninstall all`
(or `minimal`), and the clean check. Exit code is the number of failed
checks. Run both profiles before committing changes under `platform/ubuntu/`
or `common/`.

| Script | Runs after | Checks |
|---|---|---|
| `verify-basic.sh` | `./bootstrap.sh` | symlinks (incl. `~/.gitconfig.local`), packages, tools, a clean login shell, tmux config, prompt, profile recorded as full |
| `verify-optional.sh` | `./bootstrap.sh gcloud aws lima` | gcloud APT repo, aws installer, lima tarball + QEMU, completions |
| `verify-minimal.sh` | `./bootstrap.sh minimal` | the five minimal components, plain tmux theme in effect, no fonts / toolchains / `~/.gitconfig.local`, commits work without a signing key, profile recorded as minimal |
| `verify-clean.sh` | `./bootstrap.sh --uninstall ...` | everything dotx made is gone, `~/.bashrc` is the original, no package that was on the image is missing |

The verify scripts can also be run on their own inside the VM:
`limactl shell dotx-ubuntu -- bash -lc 'bash ~/dotx/tests/verify-minimal.sh'`.
