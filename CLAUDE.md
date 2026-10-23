# CLAUDE.md

All shared operating rules live in `AGENTS.md`, imported here:

@AGENTS.md

## Claude Code specifics

- `AGENTS.md` is the single source of truth for shared policy. Do not copy its rules into this file; change them there so Codex sees the same text.
- Do not run `/init` in this repository. The instruction files are maintained by hand.
- `PROJECT_STATE.md` and `PROJECT_CONTEXT.md` are not imported. Read them at the start of every task, as `AGENTS.md` section 2 requires.
- Claude Code's auto-memory is private to this machine and invisible to Codex and the external reviewer. Anything another agent needs belongs in the repository documents, not only in memory.
- Do not store changing implementation state in this file.
