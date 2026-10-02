#!/usr/bin/env bash
# tests/verify-clean.sh
# Run inside the Ubuntu test VM after `./bootstrap.sh --uninstall all`.
# Everything dotx installed must be gone, everything that was there before
# must still be there. run-in-lima.sh saves the pre-dotx state in
# /tmp/dotx-test (package list, original ~/.bashrc) before installing.
STATE="${DOTX_TEST_STATE:-/tmp/dotx-test}"
fail=0
check() { local label="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS  $label"; else echo "FAIL  $label  ($*)"; fail=$((fail+1)); fi; }
gone() { [ ! -e "$1" ] && [ ! -L "$1" ]; }

echo "--- symlinks removed"
for f in ~/.vimrc ~/.gitconfig ~/.tmux.conf ~/.tmux.conf.local ~/.bash_profile ~/.bashrc.local; do check "gone $f" gone "$f"; done
if [ -f "$STATE/bashrc.orig" ]; then
  check ".bashrc restored to the pre-dotx original" bash -c "[ -f ~/.bashrc ] && [ ! -L ~/.bashrc ] && cmp -s ~/.bashrc '$STATE/bashrc.orig'"
else
  check ".bashrc is a regular file again (no original saved to compare)" bash -c '[ -f ~/.bashrc ] && [ ! -L ~/.bashrc ]'
fi
check "no leftover backups" bash -c '! ls -a ~ | grep -q "\.backup\."'
echo "--- APT packages added or removed vs the pre-dotx baseline (expect: only base prerequisites and their deps added, nothing removed)"
if [ -f "$STATE/pkgs-baseline.txt" ]; then
  # only packages in state "installed": removed ones linger as "config-files" in dpkg's database
  dpkg-query -W -f='${Package} ${db:Status-Status}\n' | awk '$2 == "installed" {print $1}' | LC_ALL=C sort > "$STATE/pkgs-after.txt"
  LC_ALL=C sort -o "$STATE/pkgs-baseline.txt" "$STATE/pkgs-baseline.txt"
  removed=$(LC_ALL=C comm -23 "$STATE/pkgs-baseline.txt" "$STATE/pkgs-after.txt" | tr "\n" " ")
  added=$(LC_ALL=C comm -13 "$STATE/pkgs-baseline.txt" "$STATE/pkgs-after.txt" | tr "\n" " ")
  check "no pre-existing package removed" test -z "$removed"
  [ -n "$removed" ] && echo "      removed: $removed"
  echo "      added:   $added"
fi
echo "--- tool dirs removed"
for d in ~/.vim/autoload/plug.vim ~/.vim/plugged ~/.bash-git-prompt ~/.nvm ~/.pyenv ~/.local/bin/uv ~/.local/bin/uvx ~/.cargo ~/.rustup ~/.local/bin/aws ~/.local/bin/aws_completer ~/.local/aws-cli ~/.local/bin/limactl ~/.local/bin/lima ~/.local/lima; do check "gone $d" gone "$d"; done
check "powerline fonts gone" bash -c '! ls ~/.local/share/fonts 2>/dev/null | grep -qi powerline'
echo "--- packages removed"
# packages dotx installed itself must be gone; ones that were on the image before dotx must still be there
for p in vim tmux pipx google-cloud-cli; do
  if [ -f "$STATE/pkgs-baseline.txt" ] && grep -qx "$p" "$STATE/pkgs-baseline.txt"; then
    check "pkg $p kept (pre-existing)" bash -c "dpkg-query -W -f='\${db:Status-Status}' $p 2>/dev/null | grep -qx installed"
  else
    check "pkg $p removed" bash -c "! dpkg-query -W -f='\${db:Status-Status}' $p 2>/dev/null | grep -qx installed"
  fi
done
check "git kept (base prerequisite)" dpkg -s git
echo "--- gcloud repo files removed"
check "keyring gone"      gone /usr/share/keyrings/cloud.google.gpg
check "sources list gone" gone /etc/apt/sources.list.d/google-cloud-sdk.list
check "dotx state dir gone" bash -c '[ ! -d ~/.local/state/dotx ]'
echo "RESULT clean: $fail failure(s)"
exit $fail
