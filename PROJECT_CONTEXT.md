# PROJECT_CONTEXT.md — Decisions and Plans

Planning context and decision rationale. This file does not describe implemented functionality; see `PROJECT_STATE.md` for that.

Last updated: 2026-10-24 (Phase 1, Claude Code)

## Product vision and goals

Source: the user's application specification of 2026-10-24 ("Godot 3D mobil oyun — başlangıç promptu").

A third-person 3D mobile game for iOS and Android, built in Godot on the user's existing İstanbul • Haliç map (see `docs/maps/istanbul_halic/README.md`).

The first playable version contains:

- one player character that can walk and run;
- a punch;
- a directional roll;
- one drivable car on the map that the player can enter, drive, and exit;
- touch-controlled camera;
- landscape screen layout;
- all core mechanics usable on iOS and Android.

Not in the first version: multiplayer, bots, missions, additional vehicles.

The systems must be modular so new maps, NPCs, AI, vehicles, and gameplay mechanics can be added later without rewriting the character and vehicle systems.

## Intended audience and platforms

- Platforms: iOS and Android from a single Godot project. Landscape orientation.
- Touch input is the primary control system. Desktop keyboard and mouse controls are optional and exist only for development and testing.
- Audience: not specified.

## Requirements by phase

Phases advance only after user approval and review of the previous phase.

### Phase 0 — Project audit and base architecture

Inspect the map, Godot version, and assets; plan the architecture; create the needed documents.

### Phase 1 — Mobile character control

On the existing map: touch joystick, third-person camera, walking, running, collision.

Touch requirements that apply from Phase 1:

- Left side: virtual analog joystick, 360° movement.
- Right side: drag to rotate the camera; run control.
- Joystick movement is relative to the camera direction.
- Several fingers work at the same time.
- Camera dragging does not conflict with buttons.
- The camera does not go inside walls.
- If a model or animation is missing, build a working placeholder and report what is missing.

### Phase 2 — Character actions

Punch button and roll button on the right side. Roll follows the movement direction. Punch and roll are managed by the animation/state system and must not break each other or locomotion.

### Phase 3 — Vehicle system

- An interaction button appears when the player is near the car.
- Entering the car hides the character controls, shows the vehicle controls, and switches the camera to vehicle follow mode.
- Vehicle controls: touch steering, throttle, brake/reverse, handbrake, exit.
- Exiting while the car is moving unsafely is blocked. Exiting restores the character controls.
- The system must support other vehicle types later.

### Phase 4 — Mobile optimization and platform validation

- Use a mobile renderer suited to the Godot version; avoid expensive shadows; review texture, material, map-size, and collision costs; avoid needless per-frame work.
- UI adapts to different phone screens and respects the safe area, notches, and screen edges. Touch buttons are comfortably large.
- Target 60 FPS. A 30 FPS mode for weaker Android devices may be considered. Neither target counts as met until measured on real devices.
- Review iOS and Android export configuration. Isolate device and platform dependencies.

### Phase 5 — Extensibility

Validate the infrastructure for adding a new map, a new vehicle, and NPCs.

### Suggested modules (from the specification)

PlayerController, PlayerStateMachine, PlayerCombat, PlayerAnimation, ThirdPersonCamera, VehicleController, VehicleInteraction, MobileInputController, WorldManager, UIController. Names and layout may follow the project's structure.

### Working rules from the specification

- Never present a non-working mechanic as complete.
- Run the Godot parser, import, and suitable automated tests.
- Mark physical iOS/Android device tests as NOT RUN when they were not performed.
- Commit after each completed stage; keep `PROJECT_STATE.md` current.

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

### D5 — Map source (2026-10-24, user confirmed)

- **Decision:** The game uses the İstanbul • Haliç Godot project from `<SOURCE_PACKAGE>/Istanbul_Halic/Godot` (placeholder explained in `docs/maps/istanbul_halic/README.md`). It was copied into the repository root; the original stays untouched.
- **Rationale:** The specification says to work on the existing project and not to create a new one, but the repository held no Godot project. Copying keeps the original safe and puts the project under Git.

### D6 — Map model kept out of Git (2026-10-24, user decision)

- **Decision:** `assets/istanbul_halic.glb` (502 MB) is ignored by Git. Restore steps and hash: `docs/maps/istanbul_halic/README.md`.
- **Rationale:** GitHub rejects files over 100 MB. Git LFS was offered and declined because of storage and bandwidth quota.
- **Consequence:** A fresh clone does not run until the GLB is copied in.

### D7 — Engine and language (2026-10-24)

- **Decision:** Godot 4.7.2 (the installed editor and export templates) with GDScript.
- **Rationale:** The map was authored for Godot 4.4 and its own validation passes unchanged on 4.7.2. Its scripts are GDScript.

## Application technical decisions

Phase 1 decisions made by the implementing agent (Claude Code, 2026-10-24). None was specified by the user; each can be revisited. Code structure: `docs/ARCHITECTURE.md`.

### T1 — Mobile renderer

- **Decision:** Mobile renderer for desktop and mobile; the map project used GL Compatibility.
- **Rationale:** The specification asks for a mobile renderer suited to the Godot version. Mobile is Godot 4's renderer for phones (Vulkan on Android, Metal on iOS) and supports occlusion culling, which Compatibility lacks and the city may need in Phase 4. Desktop measurement at the spawn view gave the same draw calls in both renderers (1330 vs 1335).
- **Revisit:** Phase 4, after device measurements. Weak Android GPUs may favor Compatibility.

### T2 — Native VirtualJoystick plus a touch router

- **Decision:** Movement uses Godot 4.7's built-in `VirtualJoystick` (dynamic mode), which writes the `move_*` input actions. Camera drag and buttons go through `MobileInputController`, which routes each finger to one control by priority and keeps it until release.
- **Rationale:** The engine control covers analog movement, dead zone, and multi-touch, and keyboard and touch share one input path. A custom joystick was written first and dropped once the native class turned up (its class name collided). The router guarantees that camera drags and buttons never take each other's fingers.

### T3 — Intent-based character control

- **Decision:** `PlayerController` reads a device-independent `PlayerIntent` (world direction, run) from a `PlayerInputSource` every physics tick. `TouchPlayerInput` is the touch implementation. Behavior lives in child-node states of `PlayerStateMachine` (Idle, Walk, Run).
- **Rationale:** NPCs and bots can drive the same character with another input source, and Phase 2 actions become new states instead of conditionals.

### T4 — Camera

- **Decision:** Top-level orbit rig with a `SpringArm3D` (0.2 m sphere, world layer, player excluded); framing in swappable `CameraProfile` resources; physics interpolation on, and the camera follows the interpolated target in `_process`.
- **Rationale:** Covers "camera must not go inside walls", lets Phase 3 switch to a vehicle profile with `set_target()`, and avoids stutter when the display rate differs from the 60 Hz physics rate.

### T5 — Maps as data

- **Decision:** A map is `maps/<name>/<name>.tscn` plus a `MapDefinition` resource. `WorldManager` loads it, provides the spawn, respawns below the kill height, and clamps to the bounds.
- **Rationale:** The specification requires new maps without rewriting character and vehicle systems.

### T6 — Vertex-color fix for the map at runtime

- **Decision:** The game's map scene enables `vertex_color_use_as_albedo` on the GLB's 6 shared materials at load. The GLB, its import settings, and the original demo are unchanged.
- **Rationale:** All map colors are stored as vertex colors with white base colors. Godot's importer does not apply them, so the city rendered white in Godot, including in the untouched original demo. The fix restores the look of the package's Blender previews without modifying the map.

### T7 — Run control

- **Decision:** Running is a toggle button on the right that switches off when the joystick finger lifts (`run_resets_on_release`). Running uses full speed whatever the stick tilt; walking speed follows the tilt. Walk 4.5 m/s and run 8.0 m/s, the original explorer's speeds.
- **Rationale:** The specification asks only for a "run control" on the right side. Holding a button while also dragging the camera is awkward with two thumbs; a toggle frees the right thumb.

### T8 — Placeholder character

- **Decision:** Orange capsule (0.35 m radius, 1.8 m tall) with a dark visor showing the facing direction.
- **Rationale:** No character model or animations exist. The specification allows a working placeholder.

### T9 — Spawn facing

- **Decision:** The player spawns facing along Galata Bridge toward Karaköy (yaw −27°), measured from deck-edge raycasts.
- **Rationale:** Facing due north led off the deck's western edge within about 9 m, and railings have no collision.

### T10 — Test approach

- **Decision:** A small custom headless runner (`tests/run_tests.gd`) with unit tests and integration tests on the real map; touches go through `Input.parse_input_event`.
- **Rationale:** No third-party test addon is needed, the runner works from the command line for every agent, and the real input pipeline is exercised.

### T11 — Layout base

- **Decision:** Keep the map project's 1440×900 base canvas; add `expand` aspect and `sensor_landscape` orientation.
- **Rationale:** Fills any phone or tablet ratio without letterboxing and keeps the original explorer demo's HUD positions valid.

## Planned features

Everything listed under "Requirements by phase" from Phase 2 onward, plus the remaining Phase 4 and 5 work.

## Agreed but unimplemented functionality

See "Requirements by phase". `PROJECT_STATE.md` records which parts exist.

## Deferred ideas

- 30 FPS mode for weaker Android devices (Phase 4, to be considered).
- Desktop keyboard and mouse controls are allowed only as development aids.

## Rejected alternatives

- **Generating instruction files with `/init`:** rejected by the bootstrap instructions in favor of hand-maintained files.
- **Duplicating the full shared policy in `CLAUDE.md`:** rejected; two copies would drift apart.
- **Storing the map GLB with Git LFS:** declined by the user on 2026-10-24 (quota cost).
- **Working directly in the Google Drive folder:** rejected; it is not under Git and the map original must stay unmodified.

## Open questions

1. Character model and animations: none exist in the map package. Where will they come from? A placeholder is used until then.
2. Car model: the map has no vehicles. Source needed before Phase 3.
3. Map performance on phones: about 7.07 million triangles and 3,055 mesh nodes. Phase 4 may need decimation, visibility ranges, occlusion culling, or map splitting. Needs device measurements first.
4. Minimum target devices, including what "weaker Android device" means for the 30 FPS mode.
5. App name, bundle/package identifiers, signing team, and keystores for iOS and Android export.
6. In-game UI language.
7. Audience and monetization: not specified.
8. Physics engine for vehicles (Godot Physics or Jolt): decide in Phase 3. The project currently uses the default engine.
9. Whether the original explorer demo (`main.tscn`, `scripts/explorer.gd`, `scripts/main.gd`) should be kept long term.
10. Branch strategy: work currently happens directly on `main`. Decide whether feature branches or pull requests are wanted.
11. Whether `.vscode/` should be committed, ignored, or left untracked. It is currently left untracked.
12. Railings, lamps, and other decor have no collision, so the player can walk off bridge decks and quays into the water (then respawns). Should invisible barriers be added along bridges and quays?
13. Run control style: is the toggle with reset on stick release (T7) what the user wants, or a hold button, or auto-run at full stick tilt?
14. HUD art: the controls are drawn with plain shapes. Is final art or an icon set planned?

## Constraints and priorities

- Safety and Git constraints: `AGENTS.md` sections 5–7.
- The map original in Google Drive must not be modified or deleted.
- Physical device results are reported as NOT RUN until actually performed.
- Current priority: review of Phases 0 and 1. Phase 2 starts only after user approval.
