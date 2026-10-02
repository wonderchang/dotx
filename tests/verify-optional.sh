#!/usr/bin/env bash
# tests/verify-optional.sh
# Run inside the Ubuntu test VM after `./bootstrap.sh gcloud aws lima docker`.
# Prints PASS/FAIL per check; exit code = number of failures.
fail=0
check() { local label="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS  $label"; else echo "FAIL  $label  ($*)"; fail=$((fail+1)); fi; }

echo "--- gcloud (APT repo)"
check "google-cloud-cli package" dpkg -s google-cloud-cli
check "keyring"       test -f /usr/share/keyrings/cloud.google.gpg
check "sources list"  test -f /etc/apt/sources.list.d/google-cloud-sdk.list
check "gcloud runs"   gcloud --version
check "completion file exists" test -f /usr/lib/google-cloud-sdk/completion.bash.inc

echo "--- aws (official installer, user-level)"
check "aws symlink"   test -L ~/.local/bin/aws
check "aws runs"      ~/.local/bin/aws --version
check "aws_completer" test -x ~/.local/bin/aws_completer
check "install dir"   test -d ~/.local/aws-cli
check "login shell registers aws completion" bash -c 'env -i HOME=$HOME TERM=xterm USER=$USER bash -lc "complete -p aws" | grep -q aws_completer'

echo "--- lima (release tarball, user-level)"
check "limactl symlink" test -L ~/.local/bin/limactl
check "limactl runs"    ~/.local/bin/limactl --version
check "prefix dir"      test -d ~/.local/lima/share/lima
check "qemu-utils"      dpkg -s qemu-utils
check "qemu-system"     bash -c 'dpkg -s qemu-system-x86 || dpkg -s qemu-system-arm'
check "login shell registers limactl completion" bash -c 'env -i HOME=$HOME TERM=xterm USER=$USER bash -lc "complete -p limactl" | grep -q __start_limactl'

echo "--- docker (Docker Engine from Docker's APT repo)"
check "docker-ce package"      dpkg -s docker-ce
check "compose plugin package" dpkg -s docker-compose-plugin
check "keyring"       test -f /etc/apt/keyrings/docker.asc
check "sources list"  test -f /etc/apt/sources.list.d/docker.list
check "docker CLI runs"        docker --version
check "docker compose runs"    docker compose version
check "docker buildx runs"     docker buildx version
check "daemon active"          systemctl is-active --quiet docker
check "user in docker group"   bash -c 'id -nG "$USER" | tr " " "\n" | grep -qx docker'
check "daemon reachable via the docker group (sg, no re-login)" sg docker -c "docker info"
check "login shell registers docker completion" bash -c 'env -i HOME=$HOME TERM=xterm USER=$USER bash -lc "complete -p docker" | grep -q docker'

echo "RESULT optional: $fail failure(s)"
exit $fail
