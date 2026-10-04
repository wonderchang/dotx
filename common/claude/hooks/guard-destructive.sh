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

# Report what matched and where, not just the category: the command may be
# a long heredoc in which one line is the problem, and the person at the
# prompt has to be able to spot it without reading the whole thing.
lines = cmd.split("\n")
hits = []
for label, pattern in RULES:
    m = re.search(pattern, cmd)
    if not m:
        continue
    # Some patterns consume the separator before the command (which may be
    # the newline), so step past leading whitespace before locating it
    pos = m.start()
    while pos < len(cmd) and cmd[pos].isspace():
        pos += 1
    lineno = cmd.count("\n", 0, pos) + 1
    line = lines[lineno - 1].strip()
    if len(line) > 90:
        col = pos - (cmd.rfind("\n", 0, pos) + 1) - (len(lines[lineno - 1]) - len(lines[lineno - 1].lstrip()))
        lo = max(0, col - 30)
        line = ("…" if lo else "") + line[lo:lo + 90] + ("…" if lo + 90 < len(line) else "")
    where = f"line {lineno} of {len(lines)}" if len(lines) > 1 else "the command"
    hits.append(f"{label} at {where}: {line}")
    if len(hits) == 3:
        break

if hits:
    reason = "dotx safety hook flagged " + "; ".join(hits) + ". Destructive or discards work: confirm with the user first."
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": reason,
        }
    }))
sys.exit(0)
PY

exec python3 -c "$PY_SCRIPT"
