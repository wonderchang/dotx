#!/usr/bin/env bash
# tests/verify-basic.sh
# Run inside the Ubuntu test VM after `./bootstrap.sh` (the basic set).
# Prints PASS/FAIL per check; exit code = number of failures.
# DOTX_DIR is where the repo was synced to in the VM (default ~/dotx).
DOTX_DIR="${DOTX_DIR:-$HOME/dotx}"
fail=0
check() {  # check "label" cmd...
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "PASS  $label"; else echo "FAIL  $label  ($*)"; fail=$((fail+1)); fi
}
link_to() { [ -L "$1" ] && [ "$(readlink -f "$1")" = "$(readlink -f "$2")" ]; }

echo "--- symlinks"
check ".vimrc"        link_to ~/.vimrc        "$DOTX_DIR"/common/vim/.vimrc
check ".gitconfig"    link_to ~/.gitconfig    "$DOTX_DIR"/common/git/.gitconfig
check ".tmux.conf"    link_to ~/.tmux.conf    "$DOTX_DIR"/common/tmux/.tmux.conf
check ".tmux.conf.local" link_to ~/.tmux.conf.local "$DOTX_DIR"/common/tmux/.tmux.conf.local
check ".bashrc"       link_to ~/.bashrc       "$DOTX_DIR"/common/bash/.bashrc
check ".bash_profile" link_to ~/.bash_profile "$DOTX_DIR"/common/bash/.bash_profile
check ".bashrc.local" link_to ~/.bashrc.local "$DOTX_DIR"/platform/ubuntu/.bashrc.ubuntu
check ".gitconfig.local" link_to ~/.gitconfig.local "$DOTX_DIR"/platform/ubuntu/.gitconfig.ubuntu
check "bgp theme"     link_to ~/.bash-git-prompt/themes/WonderChang.bgptheme "$DOTX_DIR"/common/bash/WonderChang.bgptheme
check "claude CLAUDE.md" link_to ~/.claude/CLAUDE.md "$DOTX_DIR"/common/claude/CLAUDE.md
check "claude rules/"    link_to ~/.claude/rules     "$DOTX_DIR"/common/claude/rules
check "claude hook"      link_to ~/.claude/hooks/guard-destructive.sh "$DOTX_DIR"/common/claude/hooks/guard-destructive.sh
check "claude hook registered" bash -c 'python3 -c "import json,sys,os; s=json.load(open(os.path.expanduser(\"~/.claude/settings.json\"))); sys.exit(0 if any(h[\"command\"].endswith(\"/hooks/guard-destructive.sh\") for e in s[\"hooks\"][\"PreToolUse\"] for h in e[\"hooks\"]) else 1)"'
check "claude hook asks on rm -rf" bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf x\"}}" | ~/.claude/hooks/guard-destructive.sh | grep -q "\"ask\""'
check "no .tmux.conf.plain (full profile)" bash -c '[ ! -e ~/.tmux.conf.plain ] && [ ! -L ~/.tmux.conf.plain ]'
check "profile file says full" bash -c '[ "$(cat ~/.local/state/dotx/profile)" = full ]'

echo "--- packages"
check "vim"  dpkg -s vim
check "git"  dpkg -s git
check "tmux" dpkg -s tmux
check "htop" dpkg -s htop
check "pipx" dpkg -s pipx

echo "--- tools"
check "vim-plug"        test -f ~/.vim/autoload/plug.vim
check "vim plugins dir" bash -c 'ls ~/.vim/plugged | grep -q .'
check "bash-git-prompt" test -f ~/.bash-git-prompt/gitprompt.sh
check "powerline fonts" bash -c 'fc-list 2>/dev/null | grep -qi powerline || ls ~/.local/share/fonts | grep -qi powerline'
check "nvm"   test -s ~/.nvm/nvm.sh
check "pyenv" test -x ~/.pyenv/bin/pyenv
check "uv"    test -x ~/.local/bin/uv
check "uvx"   test -x ~/.local/bin/uvx
check "rustup" test -x ~/.cargo/bin/rustup
check "cargo"  test -x ~/.cargo/bin/cargo

echo "--- fresh login shell loads cleanly and sees the tools"
out=$(env -i HOME=$HOME TERM=xterm USER=$USER bash -lc 'type nvm pyenv uv cargo >/dev/null && echo OK' 2>&1)
check "login shell: nvm pyenv uv cargo resolvable" test "$out" = "OK"
# interactive shells need a pty, otherwise bash itself prints job-control noise
noise=$(script -q -c "env -i HOME=$HOME TERM=xterm USER=$USER bash -lic true" /dev/null 2>&1 | tr -d '\r' | grep -v '^$')
check "interactive login shell: no noise" test -z "$noise"
[ -n "$noise" ] && echo "      output: $noise"
dups=$(env -i HOME=$HOME TERM=xterm USER=$USER bash -lc 'echo "$PATH"' | tr ':' '\n' | sort | uniq -d | wc -l)
check "login shell: PATH has no duplicates" test "$dups" -eq 0

echo "--- tmux config parses (embedded bash functions)"
check "tmux -f .tmux.conf" bash -c 'tmux -f ~/.tmux.conf -L dotxtest new-session -d "sleep 1" && tmux -L dotxtest kill-server'
check "cut -c3- | bash (apply_configuration)" bash -c 'cut -c3- ~/.tmux.conf | bash -s apply_configuration >/dev/null 2>&1; true'

echo "--- rust/uv installers did not leave lines in rc files"
check "no uv env line" bash -c '! grep -q "\.local/bin/env" ~/.bashrc ~/.profile ~/.bash_profile 2>/dev/null'
check "no cargo env line" bash -c '! grep -q "\.cargo/env" ~/.profile ~/.bash_profile 2>/dev/null'

echo "RESULT basic: $fail failure(s)"
exit $fail
