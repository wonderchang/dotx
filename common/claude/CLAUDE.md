# Global Instructions

Personal defaults for every project. Project CLAUDE.md files add to these;
when they conflict, follow the project.

## Language

- Reply in the language I write in. For Chinese, use Traditional Chinese with
  Taiwan usage, never Simplified.
- Keep technical terms, commands and identifiers in English.
- Write code, comments, commit messages and docs in English unless the project
  says otherwise.

## Safety

- Never run destructive or irreversible actions without asking first, even in
  auto mode: force push, rewriting published history, deleting branches,
  dropping data, `rm -rf`, and anything that discards uncommitted work
  (`git reset --hard`, `git checkout -- <file>`, `git stash drop`).
- Never print, commit or send credentials, tokens or `.env` contents. Say where
  they are instead.
