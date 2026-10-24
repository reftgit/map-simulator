# PROJECT_CONTEXT.md — Decisions and Plans

Planning context and decision rationale. This file does not describe implemented functionality; see `PROJECT_STATE.md` for that.

Last updated: 2026-10-24 (Phase 1 device validation, Claude Code)

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

### D8 — App identifiers and temporary iOS team (2026-10-24, user decision)

- **Decision:** Android package `com.mirongi.mapsimulator`. iOS debug builds use the temporary bundle ID `com.mirongi.mapsimulator.dev` under the user's current Apple team `8N7RYA42S6`. The final iOS bundle ID `com.mirongi.mapsimulator` is **not registered with any Apple team** and must not be registered by Xcode automatically; it will be registered in the user's future Apple Developer account.
- **When the account changes:** update `application/app_store_team_id` and, if needed, the temporary bundle ID in `export_presets.cfg`, and record it here.
- **Rationale:** On Apple's side a bundle ID is bound to the team that registers it, so registering the final ID now would tie it to the wrong account. (The team ID was confirmed by the user in the session because the input field had been left as a placeholder; it was the only team on the build Mac.)

### D9 — iOS signing without portal changes (2026-10-24)

- **Decision:** The "iOS Debug" preset exports only the Xcode project (`export_project_only=true`); `tools/build_ios_debug.sh` builds it with automatic signing and **without** `-allowProvisioningUpdates`, so `xcodebuild` cannot contact the Apple Developer portal, register App IDs, or create profiles. It signs with a matching profile already on the Mac (the team's Xcode-managed wildcard "iOS Team Provisioning Profile: *").
- **Rationale:** Implements D8's no-registration rule. Manual signing with the wildcard profile was tried and rejected by Xcode ("profile is Xcode managed, but signing settings require a manually managed profile"). After the build, the local profile folder held the same 5 profiles, none created that day.

### D10 — Android debug signing (2026-10-24, user decision)

- **Decision:** Debug APKs are signed with the Godot editor's debug keystore, configured in the local editor settings. `export_presets.cfg` holds no keystore path, user, or password. A release keystore is out of scope for now.

## Application technical decisions

Decisions made by the implementing agent (Claude Code, 2026-10-24). None was specified by the user unless stated; each can be revisited. Code structure: `docs/ARCHITECTURE.md`.

### T1 — Mobile renderer

- **Decision:** Mobile renderer for desktop and mobile; the map project used GL Compatibility.
- **Rationale:** The specification asks for a mobile renderer suited to the Godot version. Mobile is Godot 4's renderer for phones (Vulkan on Android, Metal on iOS) and supports occlusion culling, which Compatibility lacks and the city may need in Phase 4. Desktop measurement at the spawn view gave the same draw calls in both renderers (1330 vs 1335).
- **Device data (2026-10-24, debug builds):** runs on both test devices: Vulkan 1.1.128 Forward Mobile on the Galaxy Tab A7 (Adreno 610) at 5–8 FPS; Metal Forward Mobile on the iPhone 13 Pro at 89 FPS cold at the spawn, 43–53 FPS at street level after long use in a "Serious" thermal state. Full numbers in `PROJECT_STATE.md`. Compatibility was not measured on the devices, so the comparison is still open.
- **Revisit:** Phase 4 or an earlier performance pass. Occlusion culling (Mobile only) has not been tried yet.

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

### T12 — Errors fail tests; skips are visible

- **Decision:** The runner registers a `Logger` (`OS.add_logger`) and fails any test during which an engine, script, or shader error is logged; integration tests report SKIP without the map GLB; exit codes 0 / 1 / 2 (clean / failure / skipped).
- **Rationale:** GDScript runtime errors abort only the failing function, so a crashed test looked like a pass. A completion flag set by the caller cannot detect that; a logger can, without parsing output.

### T13 — Input reset on focus loss and pause

- **Decision:** `release_all_touches()` also turns off the run toggle, releases the `move_*` and `run` actions, and pushes a touch release for indices 0–9 so the native `VirtualJoystick` (which has no reset API) forgets its finger.
- **Rationale:** Releasing actions alone is not enough: the joystick would press them again on the next drag from the old finger.

### T14 — Debug measurement tools

- **Decision:** Debug builds show render and memory statistics, log them as `PERF` lines, log `STARTUP` times, and offer a VIEW button that cycles fixed viewpoints defined in `MapDefinition`.
- **Rationale:** Device numbers must be repeatable and readable without an attached profiler. Release builds are unaffected.

### T15 — App name and icon for debug builds

- **Decision:** Debug builds show the project name "İstanbul • Haliç" and a placeholder icon (`icon.svg`, the capsule character over water). No app name was provided; iOS export requires an icon.

### T16 — Export resources: no exported PackedStringArray

- **Decision:** Exported script properties use `Array[String]`, never `PackedStringArray`; a unit test enforces this for `game/` and `maps/`.
- **Rationale:** Godot 4.7.2's export conversion of text resources dropped an exported `PackedStringArray` (`MapDefinition.debug_viewpoint_names`) while keeping the neighbouring `Array[Transform3D]`; the device build then crashed on VIEW. The same data as `Array[String]` survived. Reproduced with ASCII-only names and a fresh export cache.

## Performance findings and candidate measures

Findings (2026-10-24, debug builds, details in `PROJECT_STATE.md`): street-level frames draw 0.95–1.5 k draw calls and 2.3–3.4 M primitives, including in a narrow Galata street facing a wall, so hidden geometry is drawn. The Galaxy Tab A7 runs at 5–8 FPS with PSS ~520 MB plus swap and 10–21 s to the first frame. The iPhone 13 Pro starts in 1.6 s and runs at 89 FPS cold, but enters a "Serious" thermal state within minutes and falls to 43–53 FPS.

Candidate measures, none implemented, to be measured one at a time (Phase 4 or an earlier pass if approved):

- Occlusion culling (Mobile renderer) with occluders from building footprints or baked from the GLB.
- Visibility ranges (HLOD-style fade) for the 4,008 lamps, 5,477 trees, shrubs, road paint, and facade detail; these are the bulk of mesh nodes.
- Shorter camera far plane (now 1500 m) with distance fog.
- Shadows: lower distance, single split, or off on weak devices.
- 3D render scale (`scaling_3d`) below 1.0 on weak devices.
- Frame-rate cap at 60 on 120 Hz iPhones, and the 30 FPS mode from the specification, to reduce heat.
- Faster startup: splitting the 195 MB imported map scene or streaming chunks.

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
3. Map performance on phones: measured on 2026-10-24 (see "Performance findings"). Which measures to apply, and in which phase?
4. Minimum target devices, including what "weaker Android device" means for the 30 FPS mode. Is the Galaxy Tab A7 (Snapdragon 662 / Adreno 610, 5–8 FPS today) a device that must reach 30 FPS?
5. App name and final icon; Android release keystore. (Identifiers and debug signing are decided: D8–D10.)
6. In-game UI language.
7. Audience and monetization: not specified.
8. Physics engine for vehicles (Godot Physics or Jolt): decide in Phase 3. The project currently uses the default engine.
9. Whether the original explorer demo (`main.tscn`, `scripts/explorer.gd`, `scripts/main.gd`) should be kept long term.
10. Branch strategy: work currently happens directly on `main`. Decide whether feature branches or pull requests are wanted.
11. Whether `.vscode/` should be committed, ignored, or left untracked. It is currently left untracked.
12. Railings, lamps, and other decor have no collision, so the player can walk off bridge decks and quays into the water (then respawns). Should invisible barriers be added along bridges and quays?
13. Run control style: is the toggle with reset on stick release (T7) what the user wants, or a hold button, or auto-run at full stick tilt?
14. HUD art: the controls are drawn with plain shapes. Is final art or an icon set planned?
15. Thermal budget on iPhone: is a 60 FPS cap acceptable on 120 Hz devices, and how long must a session stay out of "Serious"?
16. Startup target: the tablet needs 10–21 s to the first frame. What is acceptable?
17. Mobile vs Compatibility renderer on the weak Android device: worth measuring before Phase 4 work starts?
18. Next step: Phase 2 as planned, or a measurement-only performance pass first (recommended in `PROJECT_STATE.md`)?

## Constraints and priorities

- Safety and Git constraints: `AGENTS.md` sections 5–7.
- The map original in the source package must not be modified or deleted.
- Physical device results are reported as NOT RUN until actually performed.
- No store, TestFlight, or Play Console uploads; no release signing without explicit approval.
- Current priority: review of the Phase 1 device results and the user's decision on the next step.
