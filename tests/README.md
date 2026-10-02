# tests

End-to-end verification of the Ubuntu side in a throwaway Lima VM.

```bash
tests/run-in-lima.sh          # reuse (or create) the dotx-ubuntu VM
tests/run-in-lima.sh --fresh  # recreate the VM first: the strict, fresh-machine run
tests/run-in-lima.sh --stop   # stop the VM afterwards
```

It syncs the working tree into the VM, snapshots the installed packages and
`~/.bashrc`, then runs `./bootstrap.sh all`, the checks below, a second
install (must be a no-op), `./bootstrap.sh --uninstall all`, and the clean
check. Exit code is the number of failed checks.

| Script | Runs after | Checks |
|---|---|---|
| `verify-basic.sh` | `./bootstrap.sh` | symlinks, packages, tools, a clean login shell, tmux config, prompt |
| `verify-optional.sh` | `./bootstrap.sh gcloud aws lima` | gcloud APT repo, aws installer, lima tarball + QEMU, completions |
| `verify-clean.sh` | `./bootstrap.sh --uninstall all` | everything dotx made is gone, `~/.bashrc` is the original, no package that was on the image is missing |

The verify scripts can also be run on their own inside the VM:
`limactl shell dotx-ubuntu -- bash -lc 'bash ~/dotx/tests/verify-basic.sh'`.
