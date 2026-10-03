#!/usr/bin/env bash
# tests/verify-minimal.sh
# Run inside the Ubuntu test VM after `./bootstrap.sh minimal`.
# The shell experience must be complete, the stylish and workstation parts
# must be absent. Prints PASS/FAIL per check; exit code = number of failures.
DOTX_DIR="${DOTX_DIR:-$HOME/dotx}"
fail=0
check() {  # check "label" cmd...
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "PASS  $label"; else echo "FAIL  $label  ($*)"; fail=$((fail+1)); fi
}
link_to() { [ -L "$1" ] && [ "$(readlink -f "$1")" = "$(readlink -f "$2")" ]; }
gone() { [ ! -e "$1" ] && [ ! -L "$1" ]; }

echo "--- symlinks"
check ".vimrc"           link_to ~/.vimrc           "$DOTX_DIR"/common/vim/.vimrc
check ".gitconfig"       link_to ~/.gitconfig       "$DOTX_DIR"/common/git/.gitconfig
check ".tmux.conf"       link_to ~/.tmux.conf       "$DOTX_DIR"/common/tmux/.tmux.conf
check ".tmux.conf.local" link_to ~/.tmux.conf.local "$DOTX_DIR"/common/tmux/.tmux.conf.local
check ".tmux.conf.plain" link_to ~/.tmux.conf.plain "$DOTX_DIR"/common/tmux/.tmux.conf.plain
check ".bashrc"          link_to ~/.bashrc          "$DOTX_DIR"/common/bash/.bashrc
check ".bash_profile"    link_to ~/.bash_profile    "$DOTX_DIR"/common/bash/.bash_profile
check ".bashrc.local"    link_to ~/.bashrc.local    "$DOTX_DIR"/platform/ubuntu/.bashrc.ubuntu
check "bgp theme"        link_to ~/.bash-git-prompt/themes/WonderChang.bgptheme "$DOTX_DIR"/common/bash/WonderChang.bgptheme
check "no ~/.gitconfig.local (no signing key, no SSH rewrite)" gone ~/.gitconfig.local

echo "--- profile remembered"
check "profile file says minimal" bash -c '[ "$(cat ~/.local/state/dotx/profile)" = minimal ]'
# a bare re-run must stay minimal: no toolchains, no fonts
bare=$(cd "$DOTX_DIR" && ./bootstrap.sh --dry-run 2>&1)
check "bare ./bootstrap.sh resolves to minimal"  bash -c "grep -q 'Profile: minimal' <<< '$bare'"
check "bare ./bootstrap.sh would not touch nvm/pyenv/rust" bash -c "! grep -qE '^=== (NVM|pyenv Setup|Rust Setup|pipx)' <<< '$bare'"
check "bare ./bootstrap.sh would not install fonts" bash -c "grep -q 'Powerline fonts skipped' <<< '$bare'"

echo "--- packages"
check "vim"  dpkg -s vim
check "git"  dpkg -s git
check "tmux" dpkg -s tmux
check "htop" dpkg -s htop

echo "--- shell experience present"
check "vim-plug"        test -f ~/.vim/autoload/plug.vim
check "vim plugins dir" bash -c 'ls ~/.vim/plugged | grep -q .'
check "bash-git-prompt" test -f ~/.bash-git-prompt/gitprompt.sh

echo "--- stylish and workstation parts absent"
check "no powerline fonts" bash -c '! ls ~/.local/share/fonts 2>/dev/null | grep -qi powerline'
for d in ~/.nvm ~/.pyenv ~/.local/bin/uv ~/.cargo ~/.rustup; do check "no $d" gone "$d"; done
check "pipx not installed by dotx" bash -c '! test -f ~/.local/state/dotx/apt/pipx'
# build-essential is a dependency of rust and pyenv, neither of which is minimal
STATE="${DOTX_TEST_STATE:-/tmp/dotx-test}"
if [ -f "$STATE/pkgs-baseline.txt" ] && ! grep -qx build-essential "$STATE/pkgs-baseline.txt"; then
  check "no build-essential (nothing to compile in minimal)" bash -c '! dpkg-query -W -f="${db:Status-Status}" build-essential 2>/dev/null | grep -qx installed'
fi

echo "--- git works without a signing key, clones stay on HTTPS"
tmp=$(mktemp -d)
check "commit succeeds (no gpgsign)" bash -c "cd '$tmp' && git init -q && git commit -q --allow-empty -m test"
check "no github SSH rewrite" bash -c '[ -z "$(git config --global --get url.git@github.com:.insteadOf)" ]'
check "aliases present (git st)" bash -c "cd '$tmp' && git st"
rm -rf "$tmp"

echo "--- fresh login shell loads cleanly"
noise=$(script -q -c "env -i HOME=$HOME TERM=xterm USER=$USER bash -lic true" /dev/null 2>&1 | tr -d '\r' | grep -v '^$')
check "interactive login shell: no noise" test -z "$noise"
[ -n "$noise" ] && echo "      output: $noise"
dups=$(env -i HOME=$HOME TERM=xterm USER=$USER bash -lc 'echo "$PATH"' | tr ':' '\n' | sort | uniq -d | wc -l)
check "login shell: PATH has no duplicates" test "$dups" -eq 0

echo "--- tmux: config parses and the plain theme is in effect"
check "tmux -f .tmux.conf" bash -c 'tmux -f ~/.tmux.conf -L dotxmin new-session -d "sleep 2" && sleep 1 && tmux -L dotxmin show -gv status-left | grep -q . && tmux -L dotxmin kill-server'
# powerline separators are U+E0B0/U+E0B2 (private use); the plain theme uses '|'
check "no powerline glyphs in status line" bash -c 'tmux -f ~/.tmux.conf -L dotxmin2 new-session -d "sleep 2" && sleep 1; out=$(tmux -L dotxmin2 show -gv status-left; tmux -L dotxmin2 show -gv status-right); tmux -L dotxmin2 kill-server; ! printf "%s" "$out" | grep -q $'"'"'\xee\x82'"'"''

echo "RESULT minimal: $fail failure(s)"
exit $fail
