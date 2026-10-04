#!/usr/bin/env bash
# tests/unit-claude-guard.sh
# Drives common/claude/hooks/guard-destructive.sh with hook JSON for commands
# that must be escalated ("ask") and commands that must pass through.
# No Claude Code needed. Exit code = number of failures.
DOTX_DIR="${DOTX_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
HOOK="$DOTX_DIR/common/claude/hooks/guard-destructive.sh"
fail=0

run_hook() {  # run_hook <tool_name> <command> -> prints decision or "pass"
  local out
  out=$(python3 -c 'import json,sys; print(json.dumps({"tool_name": sys.argv[1], "tool_input": {"command": sys.argv[2]}}))' "$1" "$2" | bash "$HOOK")
  if [ -z "$out" ]; then echo pass; else python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecision"])' <<< "$out"; fi
}
expect() {  # expect <ask|pass> <command>
  local want="$1" cmd="$2" got
  got=$(run_hook Bash "$cmd")
  if [ "$got" = "$want" ]; then echo "PASS  $want  $cmd"; else echo "FAIL  want $want got $got  $cmd"; fail=$((fail+1)); fi
}

echo "--- must ask"
expect ask 'git push --force origin main'
expect ask 'git push -f'
expect ask 'git push --force-with-lease'
expect ask 'git push origin +main'
expect ask 'git push origin --delete feature'
expect ask 'git push origin :feature'
expect ask 'git branch -D feature'
expect ask 'git branch -d feature'
expect ask 'git reset --hard HEAD~1'
expect ask 'git checkout -- src/main.rs'
expect ask 'git checkout .'
expect ask 'git restore src/main.rs'
expect ask 'git stash drop'
expect ask 'git stash clear'
expect ask 'git clean -fd'
expect ask 'rm -rf build/'
expect ask 'rm -r build'
expect ask 'rm -fr build'
expect ask 'cd /tmp && rm -rf x'
expect ask 'find . -name "*.tmp" -delete'
expect ask 'ls | xargs rm'
expect ask 'psql -c "DROP TABLE users"'
expect ask 'psql -c "truncate users"'
expect ask 'terraform destroy -auto-approve'
expect ask 'kubectl delete pod web'
expect ask 'docker system prune -af'
expect ask 'limactl delete dotx-ubuntu'
expect ask 'dd if=/dev/zero of=/dev/disk2'

echo "--- must pass"
expect pass 'git push origin main'
expect pass 'git push'
expect pass 'git status'
expect pass 'git reset HEAD~1'
expect pass 'git reset --soft HEAD~1'
expect pass 'git checkout main'
expect pass 'git checkout -b feature'
expect pass 'git restore --staged src/main.rs'
expect pass 'git stash'
expect pass 'git stash pop'
expect pass 'git branch feature'
expect pass 'git branch -a'
expect pass 'rm file.txt'
expect pass 'rm -f file.txt'
expect pass 'grep -r "rm -rf" docs/'
# a quoted mention still asks: SQL always sits in quotes, so quotes are not
# stripped, and the cost of this false positive is one extra prompt
expect ask  'echo "do not git push --force"'
expect pass 'docker ps'
expect pass 'limactl stop dotx-ubuntu'
expect pass 'npm test'
expect pass 'ls -la ~/.claude'
expect pass 'dropdb-is-not-here'

echo "--- the reason names the match and the line"
reason=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' $'cd /tmp && cat > x.sh <<EOF\necho hello\nrm -rf "$HOME/.cache/x"\nEOF\nbash x.sh' | bash "$HOOK" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecisionReason"])')
if grep -q 'recursive rm at line 3 of 5: rm -rf "$HOME/.cache/x"' <<< "$reason"; then echo "PASS  reason quotes the line"; else echo "FAIL  reason: $reason"; fail=$((fail+1)); fi
reason=$(run_hook_reason() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1" | bash "$HOOK" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecisionReason"])'; }; run_hook_reason 'git push --force && git branch -D old')
if grep -q 'force push at the command: git push --force && git branch -D old; delete branch at the command' <<< "$reason"; then echo "PASS  several rules listed"; else echo "FAIL  reason: $reason"; fail=$((fail+1)); fi

echo "--- other tools and bad input pass through"
got=$(run_hook Edit 'rm -rf /'); if [ "$got" = pass ]; then echo "PASS  Edit tool ignored"; else echo "FAIL  Edit tool: $got"; fail=$((fail+1)); fi
got=$(echo 'not json' | bash "$HOOK"); if [ -z "$got" ]; then echo "PASS  invalid JSON passes"; else echo "FAIL  invalid JSON: $got"; fail=$((fail+1)); fi

echo ""; echo "$fail failure(s)"; exit "$fail"
