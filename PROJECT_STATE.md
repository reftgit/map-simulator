# PROJECT_STATE.md — Verified Current State

What actually exists in the repository and how it was verified. Plans and decisions belong in `PROJECT_CONTEXT.md`.

Last updated: 2026-10-23 (bootstrap, Claude Code)

## Current phase

**Bootstrap.** The shared development protocol is installed. **No application implementation exists**: there is no source code, build system, dependency manifest, or test suite.

## Current objective

Receive the product specification so application development can begin.

## Git

- Branch: `main`. Remote: `origin` → `https://github.com/reftgit/map-simulator.git`. Upstream: `origin/main`.
- Relevant commits: the bootstrap documentation commit is the first commit in the repository (`git log`). A commit cannot contain its own hash; later updates should list hashes here when they matter.

## Repository contents

| Path | Tracked | Notes |
|---|---|---|
| `AGENTS.md` | yes | Shared operating rules for all coding agents. |
| `CLAUDE.md` | yes | Claude Code entry point; imports `AGENTS.md`. |
| `PROJECT_STATE.md` | yes | This file. |
| `PROJECT_CONTEXT.md` | yes | Decisions, plans, open questions. |
| `.vscode/settings.json` | no | The user's editor color settings (Peacock). Pre-existing; deliberately left untracked. No `.gitignore` exists. |

## Implemented features

None.

## Verified behaviors

| Behavior | Evidence |
|---|---|
| Claude Code loads `AGENTS.md` through the `@AGENTS.md` import in `CLAUDE.md`. | 2026-10-23: `claude -p --tools ""` run from the repository root, with no tools available, correctly quoted the report markers and the force-push rule that appear only in `AGENTS.md`. |
| The remote is reachable and was empty before bootstrap. | 2026-10-23: `git ls-remote origin` returned exit code 0 with no refs. |

## Unverified behaviors

- Codex reading `AGENTS.md`. The Codex CLI is not on `PATH` in the bootstrap environment, so loading was not tested. Verify at the start of the first Codex session.

## Known bugs and regressions

None. There is no application code.

## Technical risks

- `.vscode/` is untracked and not ignored, so an agent could stage it by mistake. `AGENTS.md` section 5 requires staging by explicit path.

## External blockers

- Product specification not supplied.

## Required manual actions

- Provide the product specification: purpose, audience, platforms, first milestone.
- Decide how `.vscode/` should be handled (see `PROJECT_CONTEXT.md`, open question 5).

## Current priorities

1. Record the product specification in `PROJECT_CONTEXT.md`.
2. Choose the technology stack and test strategy.
3. Scaffold the application with a minimal, verifiable build and test command.

## Recommended next task

Turn the user's product specification into `PROJECT_CONTEXT.md` entries (vision, audience, platforms, stack decision with rationale, first milestone), then scaffold a minimal project skeleton whose build and test commands run and pass.
