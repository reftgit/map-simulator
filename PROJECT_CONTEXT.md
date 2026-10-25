# PROJECT_CONTEXT.md — Decisions and Plans

Planning context and decision rationale. This file does not describe implemented functionality; see `PROJECT_STATE.md` for that.

Last updated: 2026-10-25 (Phase 2 character actions, Claude Code)

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

Detailed task of 2026-10-25 (user): one-shot punch/roll fields on the intent; two right-side buttons on press (not hold) plus keys; a short input buffer (~0.15–0.2 s); `PunchState` (startup/active/recovery, slowed movement, a front hitbox only in the active phase) and `RollState` (camera-relative stick direction or facing, constant speed, gravity and `move_and_slide` stay on, cooldown) as new states; rules for their interplay (D14, T18); a `CharacterVisual` interface so an AnimationTree visual can replace the placeholder; a debug training dummy that signals hits; no vehicle, NPC, damage, sound, or real model. Implementation and verification: `PROJECT_STATE.md`.

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

### D11 — Performance pass before Phase 2, with targets (2026-10-24, user decision)

- **Decision:** A measurement-only performance pass runs before Phase 2. Targets: Galaxy Tab A7 class at a stable 30 FPS; iPhone 13 Pro with a 60 FPS cap for a 10-minute session, thermal state at most "Fair", FPS ≥ 55. The pass did not have to meet them, only measure which measures could. No permanent default (renderer included) changes without a user decision.
- **Outcome:** see "Performance findings and proposed measures".

### D12 — Quality profiles and default selection (2026-10-24, user decision)

- **Decision:** The measured packages are permanent quality profiles: **high** (60 FPS cap, occlusion, 200 m visibility range for trees/lamps/decor/facade detail) and **low** (combo_e: occlusion, 400 m far plane + depth fog, 100 m ranges, 0.6 render scale, shadows off, LOD threshold 4, 30 FPS cap). Default rule: iOS → high, Android → low, anything else → none (scene defaults). No automatic GPU detection in release builds. Debug builds can switch profiles from the overlay (Q).
- **Acceptance criteria (user):** iPhone 13 Pro, 60 FPS cap, 10 minutes: thermal state ≤ Fair and average FPS ≥ 55. Galaxy Tab A7: average ≥ 30 and 1 % low ≥ 24, measured with PSS sampling off. Low is "best effort"; its visual cost (fog, no shadows, low render scale) is accepted for now; the real fix is the future facade work.
- **Differences from the measured packages:** none in values. LOD 4 is not in high because adding it on top of occlusion + 200 m changed nothing measurable (primitives 0.20 vs 0.21 M, both Nominal).
- **Known deviation (user decision, 2026-10-25):** the Galaxy Tab A7's 1 % low at the Galata viewpoint (23.1–23.4 FPS in the profile validation, criterion 24) is a known deviation that depends on the map-level facade work (open question 21). The criterion itself was not relaxed.

### D13 — Occluders baked once (2026-10-24)

- **Decision:** `tools/bake_occluders.gd` bakes the occluders into `maps/istanbul_halic/istanbul_halic_occluders.scn` (2.3 MB, committed), referenced by `MapDefinition.occluders_path`. Runtime building from collision stays as a fallback with a warning.
- **Rationale:** No dependence on collision layout at load, a quarter of the vertices (shared vertices), and the map scene stays untouched. The load-time saving is small (tablet 89 ms baked vs 114–118 ms runtime; iPhone 20 vs 21 ms).

### D14 — Phase 2 scope and defaults (2026-10-25, user decision)

- **Decision:** Phase 2 continues with the placeholder capsule (no character model or animation pack is added or researched in this task). Roll defaults: about 0.6 s, about 6 m, 0.8 s cooldown, no damage immunity; all exported and tunable. Punch and roll rules from the task: a punch pressed during a roll is buffered and runs after it; a roll can cancel the punch recovery but not its active phase; neither starts in the air; roll presses during the cooldown are ignored; focus loss or pause ends an action safely and returns to Idle.
- **Note:** the task prompt also offered, as an alternative, researching a CC0 animated character pack; that option was left as unfilled template text, so the primary choice (placeholder) was applied.

## Application technical decisions

Decisions made by the implementing agent (Claude Code, 2026-10-24). None was specified by the user unless stated; each can be revisited. Code structure: `docs/ARCHITECTURE.md`.

### T1 — Mobile renderer

- **Decision:** Mobile renderer for desktop and mobile; the map project used GL Compatibility.
- **Rationale:** The specification asks for a mobile renderer suited to the Godot version. Mobile is Godot 4's renderer for phones (Vulkan on Android, Metal on iOS) and supports occlusion culling, which Compatibility lacks and the city may need in Phase 4. Desktop measurement at the spawn view gave the same draw calls in both renderers (1330 vs 1335).
- **Device data (2026-10-24, debug builds):** runs on both test devices: Vulkan 1.1.128 Forward Mobile on the Galaxy Tab A7 (Adreno 610) at 5–8 FPS; Metal Forward Mobile on the iPhone 13 Pro at 89 FPS cold at the spawn, 43–53 FPS at street level after long use in a "Serious" thermal state. Full numbers in `PROJECT_STATE.md`. Compatibility was not measured on the devices, so the comparison is still open.
- **Revisit result (2026-10-24 performance pass):** keep Mobile; see "Renderer (T1 update)" below.

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

### T17 — Performance experiments as debug-only runtime flags

- **Decision:** Experiments are JSON-defined, debug-only runtime flags (`PerfConfig`), measured by an in-app benchmark and host scripts (`tools/perf/`). They never modify the GLB, the map scene, or import settings, and they are off unless an experiment file is supplied. Since D12 they are applied through the same `RenderSettings` as the profiles, layered on top (experiment > profile > defaults).
- **Rationale:** The task required measuring without changing defaults or the map; the same definitions can be re-run after any change for comparison.

### T18 — Punch and roll as states with explicit rules

- **Decision:** `PunchState` and `RollState` are child states of `PlayerStateMachine`; the locomotion states only start them (`PlayerState.start_buffered_action()`). Punch phases 0.10 / 0.10 / 0.25 s (startup / active / recovery), speed 0 while punching, facing locked. Roll 0.6 s / 6 m at constant speed, direction snapped at the start, 0.8 s cooldown, horizontal speed limited to 4.5 m/s when it ends. Rules beyond the user's (D14): a roll also cannot cancel the punch **startup** (only recovery is cancellable); a roll press during the roll itself is ignored like one during the cooldown (rolls do not chain); roll wins when both presses are pending; a punch can chain after a punch through the buffer.
- **Rationale:** States keep each action's timing in one place (T3). Punch timings were chosen by the implementing agent (no user values) as multiples of the 60 Hz tick; they are exported for tuning. Locking startup keeps a started punch committed, the usual convention; the user only specified recovery (cancellable) and active (not).

### T19 — Input buffer

- **Decision:** `ActionBuffer` keeps a press for 0.18 s (`PlayerController.input_buffer_time`, exported) and drops it afterwards. Blocked actions (roll during the roll and its cooldown) ignore presses instead of storing them. The buffer lives in the character, not in the touch input, so AI drivers get the same behaviour.
- **Consequence:** a punch pressed early in a 0.6 s roll (more than 0.18 s before it ends) is dropped, and a roll pressed in the first ~0.02 s of a punch expires before the recovery. Both are tested and are the intended meaning of "a short window".

### T20 — CharacterVisual interface

- **Decision:** Visual feedback goes through `CharacterVisual` (`set_locomotion(speed, on_floor)`, `play_action(action, duration, impact)`, `stop_action()`), referenced by `PlayerController.visual`. The capsule implementation (`PlaceholderCharacterVisual`) tweens on physics ticks. Gameplay timing (hitbox, phases) stays in the states; `impact` lets an animation align its contact frame. Contract and AnimationTree mapping: `docs/ARCHITECTURE.md`, "CharacterVisual extension point".
- **Rationale:** The task requires that an AnimationTree visual can be plugged in without touching the controller or the states; with the interface, swapping the `Visual` node is enough. Physics-tick tweens keep the placeholder smooth with physics interpolation.

### T21 — Hit detection only

- **Decision:** `Hitbox` (Area3D on the player, open only during the active phase) and `Hurtbox` (Area3D, physics layer 3 "hurtbox"). At most one hit per hurtbox per activation; a hit emits signals and nothing else.
- **Rationale:** The task excludes damage, NPCs, and knockback; the areas are the minimal reusable contract for later NPCs.

### T22 — Action buttons

- **Decision:** Punch (140 units, starburst icon) left of the run button and roll (124 units, circular-arrow icon) above it, bottom-right inside the safe area; they fire on touch-down and join `MobileInputController`'s priority list after the run button. The roll button fades during the cooldown. Icons are plain SVG shapes, no text, because the UI language is undecided (open question 6) and the default font lacks pictographs.
- **Rationale:** Keeps the run button (T7) where the user accepted it; both new buttons are within a thumb's reach of the corner without overlapping hit areas. Fading avoids a roll press that seems to do nothing.

### T23 — Debug training dummy

- **Decision:** A static dummy with a `Hurtbox`, toggled by a DUMMY overlay button in debug builds, placed 1.3 m in front of and 0.35 m right of the spawn (in punch reach from the spawn and visible past the capsule). Off by default.
- **Rationale:** The task asks for a hit-signalling dummy near the spawn that can be switched from the overlay. Off by default keeps benchmarks and tests comparable with earlier runs.

## Performance findings and proposed measures

Status: **measured on 2026-10-24, nothing applied.** Full tables and protocol: `PROJECT_STATE.md`, "Performance diagnosis pass". Raw data and screenshots: `docs/perf/`.

### User targets (D11, 2026-10-24)

- The performance pass runs before Phase 2 (user-approved order).
- Galaxy Tab A7 class: stable 30 FPS. iPhone 13 Pro: 60 FPS cap, 10-minute session with thermal state at most "Fair" and FPS ≥ 55.

### What costs the most

- **Facade detail** (`Detail_*`, `MosqueDetail_*`, `LandmarkDetail_*`): 64.2 % of the 7.07 M triangles and 60–72 % of the primitives drawn at street level. Hiding it took the tablet from 6.7 / 5.8 / 7.7 to 12.0 / 9.9 / 11.9 FPS. The building shells themselves are 2 %.
- **Hidden geometry:** without occlusion culling, a narrow Galata street facing a wall still draws ~1,000 draw calls; occlusion cuts that to 78.
- **Pixel fill on the tablet:** 0.75 render scale alone gave 1.5–1.7×; on the iPhone render scale changed nothing thermally.
- **Draw calls** matter less on the tablet (hiding lamps: −17 % draw calls, +0.2 FPS) but are where the iPhone's heat goes away (occlusion and visibility ranges both stopped the thermal rise; LOD, which keeps draw calls, only delayed "Fair").
- Shadows (off or single split) changed almost nothing on either device.

### Settings packages (applied as quality profiles on 2026-10-24, D12; validation in `PROJECT_STATE.md`)

| Package | Settings | Measured result | Visual cost |
|---|---|---|---|
| iPhone (A15 class) | 60 FPS cap + occlusion culling + 200 m visibility range for trees, lamps, decor, facade detail | 60.0 FPS every minute for 10 min, thermal Nominal throughout, footprint ~1.02 GiB; 1 % low ~41.5 (as in all capped runs) | Facade windows and some trees beyond ~200 m disappear (`docs/perf/ios/cap60_combo_occ_vis200_spawn.jpg`) |
| Tablet (Adreno 610 class) | occlusion + 400 m far plane with depth fog + 100 m visibility range + 0.6 render scale + shadows off + LOD threshold 4 + 30 FPS cap | 29.9–30.0 FPS average, 1 % low 25.3–26.6, min 23.6–25.1 without the memory sampler; PSS ~560 MiB | Heavy: nearby buildings lose windows (chunk granularity), no shadows, fog, soft image (`docs/perf/android/combo_c_aggressive_karakoy.jpg`) |

The tablet package (low) is a best-effort profile; the chunk-granular visibility range still blanks nearby facades until the map-level facade work is done.

### Map-level proposals (based on the attribution; none applied, the map must not be changed without approval)

| Proposal | Basis in the measurements | Expected effect (estimate) |
|---|---|---|
| Replace geometric facade detail with lighter geometry or textured/shader facades; stronger LODs for what remains | `hide_facade_detail`: −60–72 % primitives, 1.6–1.8× FPS on the tablet | Most of that gain while keeping a similar look; tablet near or above 30 FPS with fewer of the other cuts |
| Split facade detail (and trees) into cells of ~30–50 m or per building | Per-150 m-chunk visibility ranges blank nearby buildings | Visibility ranges and occlusion usable without near-field artefacts; allows a gentler tablet package |
| Merge ground, road, pavement, quay, garden meshes per chunk | `hide_ground`: −33–34 % draw calls, +0.4–1.4 FPS on the tablet | Fewer draw calls, mostly helps CPU and iPhone heat |
| MultiMesh or merged instances for lamps and trees | lamps: −16–18 % draw calls; trees: −12–19 % primitives | Small FPS gain on the tablet; draw-call reduction on the iPhone |
| Bake simplified occluders offline (building boxes) instead of building them from collision at load | Runtime build: 643 occluders, 317,518 triangles, 114–118 ms on the tablet, ~+40 MiB | Faster load, less memory; occlusion stays the biggest single measure |
| Faster startup (split or stream the 195 MB imported map) | 10–21 s to the first frame on the tablet | Not measured in this pass |

### Renderer (T1 update)

Keep the **Mobile** renderer. On the tablet, Compatibility was ~20 % faster on the unchanged scene but used ~914 MiB peak PSS instead of ~510 MiB, has no occlusion culling (Mobile with occlusion alone beat it: 10.3 / 14.0 / 16.4 vs 8.0 / 7.0 / 9.2 FPS), and it does not start on the iPhone (framebuffer creation and GLES3 shader compilation fail on iOS 26.6.1). FSR is unavailable on Mobile in Godot 4.7.2; MetalFX spatial produced no thermal benefit.

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

1. Character model and animations: none exist in the map package. Where will they come from? A placeholder is used until then (D14). The `CharacterVisual` interface (T20) is where they plug in.
2. Car model: the map has no vehicles. Source needed before Phase 3.
3. The settings packages are adopted as profiles (D12). Map-level facade work: see question 21.
4. Target device list beyond the two test devices. Does the Galaxy Tab A7 class stay a 30 FPS target given the measured visual cost?
5. App name and final icon; Android release keystore. (Identifiers and debug signing are decided: D8–D10.)
6. In-game UI language.
7. Audience and monetization: not specified.
8. Physics engine for vehicles. **Finding (2026-10-25):** the project setting `physics/3d/physics_engine` is `"DEFAULT"`, and in Godot 4.7.2 that runs **GodotPhysics3D**, not Jolt. Evidence: the world's direct space state is a `GodotPhysicsDirectSpaceState3D` and body states are `GodotPhysicsDirectBodyState3D` (in throwaway projects outside the repository, `"Jolt Physics"` gives `JoltPhysicsDirectSpaceState3D` / `JoltPhysicsDirectBodyState3D`, while `"GodotPhysics3D"` and `"DEFAULT"` both give the Godot classes); a space created through `PhysicsServer3D` keeps space parameters that Jolt ignores and is reported at exit as a `GodotSpace3D` allocation; `ClassDB` lists `GodotPhysicsServer3D` and no Jolt server class. Debug builds log it in the `STARTUP` line (`physics_3d=GodotPhysics3D (setting DEFAULT)`), and `test_active_physics_engine_is_detected` fails if it changes. The setting was not changed (user decision); the vehicle uses `VehicleBody3D` on GodotPhysics3D. Whether to switch to Jolt stays open; see the vehicle findings in `PROJECT_STATE.md`.
9. Whether the original explorer demo (`main.tscn`, `scripts/explorer.gd`, `scripts/main.gd`) should be kept long term.
10. Branch strategy: work currently happens directly on `main`. Decide whether feature branches or pull requests are wanted.
11. Whether `.vscode/` should be committed, ignored, or left untracked. It is currently left untracked.
12. Railings, lamps, and other decor have no collision, so the player can walk off bridge decks and quays into the water (then respawns). Should invisible barriers be added along bridges and quays?
13. Run control style: is the toggle with reset on stick release (T7) what the user wants, or a hold button, or auto-run at full stick tilt?
14. HUD art: the controls are drawn with plain shapes. Is final art or an icon set planned?
15. iPhone frame pacing: the 1 % low stays around 41 FPS in every 60-capped run (now also with the high profile, see `PROJECT_STATE.md`). Investigate a display-synchronized 60 Hz instead of `Engine.max_fps`? Not part of the acceptance criterion (average FPS).
16. Startup target: the tablet needs ~9–15 s to the map. What is acceptable?
17. Is a visible loss of distant facade detail (beyond ~200 m) acceptable on the iPhone long term?
18. Automatic GPU/device detection for choosing a profile (instead of the per-platform rule), e.g. for strong Android phones or older iPhones?
19. A user-facing graphics settings menu to pick the profile?
20. Bringing the map generation scripts (`<SOURCE_PACKAGE>/Istanbul_Halic/source/`) into the repository so map-level work is reproducible.
21. The map-level facade detail work (lighter facades, LODs, smaller cells): awaiting the user's decision and approval to change the map pipeline.
22. Damage system: punches only signal hits (T21). Health, damage values, and hit reactions are undefined.
23. NPCs: none yet. What should they do when hit, and should they use `PlayerController` with an AI `PlayerInputSource` (T3)?
24. Roll damage immunity (invulnerability frames): none for now (D14). Revisit once damage exists.
25. Punch tuning: the phase timings and the stop-while-punching rule (T18) were chosen by the agent. Should punching allow slow movement, or turn the body toward the stick at the start?
26. Should a roll be able to cancel the punch startup too (T18 locks it)?

## Constraints and priorities

- Safety and Git constraints: `AGENTS.md` sections 5–7.
- The map original in the source package must not be modified or deleted.
- Physical device results are reported as NOT RUN until actually performed.
- No store, TestFlight, or Play Console uploads; no release signing without explicit approval.
- Current priority: review of Phase 2 (punch and roll with the placeholder); then Phase 3 (vehicle) once its prerequisites are settled, or the map-level facade work (user decision).
