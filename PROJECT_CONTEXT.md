# PROJECT_CONTEXT.md — Decisions and Plans

Planning context and decision rationale. This file does not describe implemented functionality; see `PROJECT_STATE.md` for that.

Last updated: 2026-10-23 (bootstrap, Claude Code)

## Product vision and goals

**PENDING.** No product specification has been supplied yet. The repository is named `map-simulator`; no product requirements should be inferred from the name alone.

## Intended audience and platforms

**PENDING.** Not yet specified.

## Approved decisions

### D1 — Repository-based multi-agent workflow (2026-10-23)

- **Decision:** Development alternates between Claude Code and Codex as the active implementer, with an external web-based AI acting as reviewer. The user relays reports and prompts between them.
- **Rationale:** The agents share no conversation history, so all durable knowledge must live in the repository.
- **Details:** `AGENTS.md`.

### D2 — Instruction file layout (2026-10-23)

- **Decision:** `AGENTS.md` holds the shared rules. `CLAUDE.md` imports it with `@AGENTS.md` and adds only Claude-specific notes. Implementation state lives in `PROJECT_STATE.md`; decisions and plans live here.
- **Rationale:** Codex reads `AGENTS.md` natively and Claude Code supports imports from `CLAUDE.md`, so a single file serves both agents without drift.

### D3 — Automatic commits and conditional automatic push (2026-10-23)

- **Decision:** Agents commit verified units of work without asking, and run an ordinary non-force `git push` to the configured upstream at the end of a successfully validated task. Destructive Git operations stay forbidden without explicit authorization.
- **Rationale:** Keeps the remote current for the next agent and the reviewer while protecting history and user work.
- **Details:** `AGENTS.md` sections 5–7.

### D4 — Language conventions (2026-10-23)

- **Decision:** Agent Reports are written in Turkish (specified by the user). Repository documentation is written in English.
- **Note:** English for repository documentation was chosen by the bootstrap agent, not specified by the user. Change it here and in `AGENTS.md` section 9 if the user prefers otherwise.

## Application technical decisions

None yet. No language, framework, platform, build system, or test framework has been chosen.

## Planned features

None recorded.

## Agreed but unimplemented functionality

None recorded.

## Deferred ideas

None recorded.

## Rejected alternatives

- **Generating instruction files with `/init`:** rejected by the bootstrap instructions in favor of hand-maintained files.
- **Duplicating the full shared policy in `CLAUDE.md`:** rejected; two copies would drift apart.

## Open questions

1. Product specification: what the application is, who it is for, and what the first milestone is.
2. Target platforms and technology stack.
3. Test strategy and tooling, to be decided with the stack.
4. Branch strategy: work currently happens directly on `main`. Decide whether feature branches or pull requests are wanted.
5. Whether `.vscode/` should be committed, ignored through `.gitignore`, or left untracked. It is currently left untracked.

## Constraints and priorities

- Safety and Git constraints: `AGENTS.md` sections 5–7.
- Current priority: obtain the product specification before any application work starts.
