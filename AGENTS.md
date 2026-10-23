# AGENTS.md — Shared Operating Rules

These rules apply to every coding agent working in this repository (Claude Code, Codex, or any other). They are permanent and override habits carried over from other projects. Claude Code loads this file through `CLAUDE.md`; Codex reads it directly.

## Document map

| File | Purpose |
|---|---|
| `AGENTS.md` | HOW agents must work (this file). |
| `CLAUDE.md` | Claude Code entry point; imports this file. |
| `PROJECT_STATE.md` | WHAT has actually been implemented and verified. |
| `PROJECT_CONTEXT.md` | WHY decisions were made and WHAT is planned. |

Git history and the actual source code are the implementation evidence. Documentation describes them; it does not replace them.

## 1. Operating model

### Workflow A — Interchangeable coding agents

Claude Code and Codex work on this repository at different times, in any order. No agent knows another agent's private conversation history. Every agent reconstructs the project state from the repository: files, Git history, `AGENTS.md`, `CLAUDE.md` (when applicable), `PROJECT_STATE.md`, `PROJECT_CONTEXT.md`, and relevant architecture, product, and test documentation.

### Workflow B — Implementer and external reviewer

- **Agent A — Active Implementer:** the coding agent working inside the repository (Claude Code or Codex). It understands the task, inspects the project, implements, tests, updates persistent documentation, commits, pushes when the conditions in section 6 are met, and produces one complete Agent Report (section 8).
- **Agent B — External Reviewer:** an independent AI model in a web interface (ChatGPT, Claude, or other). It may have no repository access. It reviews Agent A's report, separates claims from evidence, identifies missing verification, risks, and defects, and writes the next implementation prompt.
- **User:** carries Agent A's report to Agent B and Agent B's next prompt to whichever coding agent is chosen. The reviewer does not control the repository.

### Development loop

1. User provides an implementation task.
2. Agent A reads the repository instructions and state (section 2).
3. Agent A implements and tests.
4. Agent A updates the persistent documents.
5. Agent A creates logical commits.
6. Agent A pushes when permitted (section 6).
7. Agent A produces one complete Agent Report and stops.
8. User passes the report to Agent B, who reviews it and writes the next prompt.
9. User passes that prompt to Claude Code or Codex, which reconstructs the state and continues.

The same coding model does not need to stay active across tasks. Persistent project knowledge must live in the repository, not in a chat transcript or an agent's private memory.

## 2. Task initialization

At the beginning of every development task:

1. Read the applicable repository instructions (`AGENTS.md`, and `CLAUDE.md` for Claude Code).
2. Read `PROJECT_STATE.md`.
3. Read `PROJECT_CONTEXT.md`.
4. Inspect `git status`, the current branch, and relevant Git history.
5. Inspect the relevant source code and tests.
6. Compare documented claims against the actual repository.
7. Identify unrelated or pre-existing user changes.
8. Understand the scope and acceptance criteria before modifying code.

A previous agent's report, or a reviewer's prompt, is not authoritative. Check its claims against the repository before relying on them.

## 3. Development discipline

- Implement only the requested scope.
- Respect the existing architecture and the project's established conventions.
- Preserve user data and unrelated changes.
- Avoid unnecessary rewrites and refactoring.
- Prefer manageable, independently verifiable implementation steps.
- Never report an untested behavior as verified.
- Distinguish tests that passed from tests that were skipped or could not run.
- Do not silently resolve significant architectural uncertainty by guessing. Record the question in `PROJECT_CONTEXT.md` and raise it in the report.

## 4. Persistent project state

- Update `PROJECT_STATE.md` when the verified implementation state meaningfully changes.
- Update `PROJECT_CONTEXT.md` when important product decisions, plans, or architectural rationale change, including future-feature discussions that matter to later work.
- Never record a plan as completed functionality.
- Do not duplicate content across files; link to the file that owns it.
- Keep changing implementation state out of `AGENTS.md` and `CLAUDE.md`.

### Consistency rules

If documentation, Git history, and source code disagree:

1. Investigate the discrepancy.
2. Check the relevant commits and tests.
3. Correct demonstrably inaccurate documentation when it is safe to do so.
4. Record unresolved uncertainty instead of guessing.
5. Include significant inconsistencies in the Agent Report.

## 5. Git discipline

- Create logical commits for meaningful, completed, appropriately verified work.
- Do not combine unrelated changes in one commit.
- Preserve the user's uncommitted changes.
- Stage files explicitly by path. Never stage a file just because it appears in `git status`; avoid `git add -A` and `git add .`.
- Include the relevant `PROJECT_STATE.md` / `PROJECT_CONTEXT.md` updates in the commit they describe.
- Record every commit hash for the Agent Report.

## 6. Automatic commit and push policy

### Automatic commits

For every development task:

1. Identify meaningful, logically complete units of work.
2. Implement and verify each unit where practical.
3. Stage only the files that belong to that unit.
4. Create a descriptive commit.
5. Include the relevant state and context documentation updates.
6. Record all created commit hashes.

Automatic commit creation is authorized by this protocol; do not wait for the user to ask after each normal task. Do not create misleading success commits for incomplete or unverified changes. If a task cannot be completed, preserve the changes safely, report their status accurately, and keep unrelated work out of commits.

### Automatic push

This protocol grants standing authorization for ordinary, non-force `git push` to the current branch's configured upstream after successful validation. Do not ask for confirmation on each routine qualifying push.

Before pushing, confirm all of the following:

1. The branch and its configured remote tracking branch.
2. The relevant tests passed and there are no disqualifying new failures.
3. There are no unresolved merge conflicts.
4. The commits contain only intended changes.
5. No secrets, credentials, or unintended private files are being committed.
6. Normal branch and repository policies permit the operation.

Then run a normal `git push` to the configured upstream.

- If there is no configured remote or upstream, keep the verified commits local and report that the push was skipped.
- If the push fails, keep the local commits and report the actual failure.
- Never report a push as successful unless it was.

Never, without explicit authorization:

- use `git push --force` or `--force-with-lease`;
- rewrite history;
- use destructive reset commands to resolve conflicts;
- delete remote branches;
- bypass protected-branch rules;
- push when required validation failed;
- push unrelated user changes;
- create or guess a remote destination;
- attempt automatic conflict resolution that could discard work.

Push authorization does not authorize creating a release, deploying to production, or publishing to an app store.

### Push timing

- Commit after each meaningful, verified unit.
- Push once, at the successful end of the task. Do not push after every minor edit.
- Report whether the final HEAD was pushed.

### Environment limitations

If the execution environment requires extra authorization, credentials, or network access, respect those controls. Standing Git permission in this file does not override external security controls.

## 7. Prohibited unsupervised operations

Without explicit user authorization, do not:

- force push;
- rewrite Git history;
- hard reset or discard existing user work;
- delete unrelated project files;
- run destructive production migrations;
- delete or modify live production data;
- publish applications;
- deploy to production;
- change paid infrastructure plans;
- expose credentials;
- disable security checks to make tests pass;
- make unrelated architectural changes.

Normal local builds, tests, validated commits, and qualifying ordinary pushes remain authorized.

## 8. Mandatory single-block Agent Report

Every development task ends with exactly one self-contained Agent Report.

- Put the entire report inside one Markdown code fence so the user can copy it in one action.
- Do not split it across blocks, put handoff information outside it, or nest code fences inside it.
- Write the content in Turkish. Keep technical identifiers, commands, file names, and commit hashes exactly as they are. Keep the markers and section headings from the template below unchanged so reviewers can rely on the structure.
- Do not omit important negative results. A reviewer without repository access must be able to understand the task, the actual changes, the tests, unresolved risks, and the Git delivery status without the agent's private conversation history.
- After delivering the report, stop. Do not start a new development task on your own.

Template:

```text
BEGIN_AGENT_REPORT

PROJECT:
ROLE: Agent A — Active Implementer
AGENT: Claude Code / Codex
DATE:
BRANCH:

1. TASK RECEIVED
- Original objective
- Scope
- Acceptance criteria

2. STARTING STATE
- Starting HEAD
- Initial Git status
- Existing relevant implementation
- Pre-existing user modifications

3. WORK COMPLETED
- Implemented changes
- Why they were needed
- Resulting behavior

4. FILES CHANGED
- Added files
- Modified files
- Removed files
- Purpose of each significant change

5. TECHNICAL DECISIONS
- Important implementation choices
- Architectural considerations
- Tradeoffs

6. TESTS AND VALIDATION
- Exact commands or procedures
- Test environments
- PASS / FAIL / NOT RUN
- Important measurements or observations

7. VERIFIED VS UNVERIFIED
- Independently verified outcomes
- Reported but unverified outcomes
- Missing device or integration verification

8. ISSUES AND RISKS
- Known bugs
- Potential regressions
- Technical risks
- Outstanding uncertainties

9. GIT STATUS
- Starting commit
- All commits created
- Final HEAD
- Final branch
- Remote and upstream
- Push attempted: YES / NO
- Push result: SUCCESS / FAILED / SKIPPED
- Remaining uncommitted changes

10. PROJECT DOCUMENTATION
- PROJECT_STATE.md updates
- PROJECT_CONTEXT.md updates
- Other documentation changes

11. BLOCKERS AND MANUAL ACTIONS
- External dependencies
- Required user actions
- Environment limitations

12. RECOMMENDED NEXT TASK
- One concrete next development task
- Its rationale
- Suggested acceptance criteria

13. REVIEWER ATTENTION
- Parts needing independent review
- Claims that require additional evidence
- Important concerns for the next agent

14. FINAL STATUS
COMPLETE / PARTIAL / BLOCKED

END_AGENT_REPORT
```

## 9. Language conventions

- Agent Reports: Turkish content, English structure (section 8).
- Repository documentation and instruction files: English, so every agent and reviewer reads the same text.
