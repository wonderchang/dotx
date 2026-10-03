#!/usr/bin/env bash
# common/claude/hooks/guard-destructive.sh
# Claude Code PreToolUse hook (matcher: Bash). Enforces the Safety rule in
# CLAUDE.md: a command that is destructive or discards work is turned into a
# permission prompt ("ask"), even in auto mode. It never denies outright, and
# anything it does not recognise passes through untouched.
#
# Input: hook JSON on stdin (tool_input.command). Output: a PreToolUse
# decision on stdout, or nothing. Exit 0 always; a hook error must not block
# ordinary work. Test with tests/unit-claude-guard.sh.

command -v python3 >/dev/null 2>&1 || exit 0

# The script goes in through -c so that stdin stays the hook JSON
read -r -d '' PY_SCRIPT <<'PY' || true
import json, re, sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if data.get("tool_name") != "Bash":
    sys.exit(0)
cmd = (data.get("tool_input") or {}).get("command") or ""

# (label, regex). Matched against the whole command string, so chained
# commands (`a && b`) are covered. Case-insensitive only where noted.
RULES = [
    ("force push",                 r"\bgit\s+push\b[^|;&]*\s(--force\b|--force-with-lease\b|-[a-zA-Z]*f[a-zA-Z]*\b)"),
    ("force push (+refspec)",      r"\bgit\s+push\b[^|;&]*\s\+\S+"),
    ("delete remote branch",       r"\bgit\s+push\b[^|;&]*\s(--delete\b|:\S+)"),
    ("delete branch",              r"\bgit\s+branch\s+(-[a-zA-Z]*[dD][a-zA-Z]*|--delete)\b"),
    ("discard changes",            r"\bgit\s+reset\s+(--hard|--merge)\b"),
    ("discard changes",            r"\bgit\s+checkout\s+(--\s|\.(\s|$)|-f\b|--force\b)"),
    ("discard changes",            r"\bgit\s+restore\b(?![^|;&]*--staged)"),
    ("drop stash",                 r"\bgit\s+stash\s+(drop|clear)\b"),
    ("delete untracked files",     r"\bgit\s+clean\b[^|;&]*\s-[a-zA-Z]*[fdx]"),
    ("rewrite history",            r"\bgit\s+(filter-branch|filter-repo)\b"),
    ("recursive rm",               r"(^|[\s;&|(])rm\s+(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)\b"),
    ("rm via xargs",               r"\bxargs\b[^|;&]*\brm\b"),
    ("find -delete",               r"\bfind\b[^|;&]*\s-delete\b"),
    ("drop data (SQL)",            r"(?i)\b(drop\s+(table|database|schema|index)|truncate\s+table|truncate)\b"),
    ("destroy infrastructure",     r"\b(terraform|tofu|pulumi)\s+destroy\b"),
    ("delete k8s resources",       r"\bkubectl\s+delete\b"),
    ("prune docker",               r"\bdocker\s+(system|volume|container|image|network|builder)\s+prune\b"),
    ("remove docker volume",       r"\bdocker\s+volume\s+rm\b"),
    ("delete VM",                  r"\b(limactl|colima)\s+delete\b"),
    ("overwrite disk",             r"(^|[\s;&|])(dd\s+if=|mkfs(\.\w+)?\s)"),
]

for label, pattern in RULES:
    if re.search(pattern, cmd):
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "ask",
                "permissionDecisionReason":
                    f"dotx safety hook: {label}. This command is destructive or discards work; "
                    f"confirm with the user before running it.",
            }
        }))
        break
sys.exit(0)
PY

exec python3 -c "$PY_SCRIPT"
