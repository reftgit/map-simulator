# PROJECT_CONTEXT.md — Decisions and Plans

Planning context and decision rationale. This file does not describe implemented functionality; see `PROJECT_STATE.md` for that.

Last updated: 2026-11-02 (the shader facade map as the default, Claude Code)

## Main goal (D26, 2026-11-02, user decision)

**The project is a map infrastructure.** Any map (GLB) a user provides that follows the documented map contract (`docs/MAP_CONTRACT.md`) must become playable automatically: the character walks, punches, and rolls, the car drives, NPCs patrol, and the quality profiles apply. For a map that does not follow the contract, the import tool reports what is missing and how to fix it, and fixes what it can by itself. Every later task, the streaming loader included, is designed for maps in general, not for one map.

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

Detailed task of 2026-10-25 (user): first identify and log the active 3D physics engine without changing it; vehicle with `VehicleBody3D` on that engine (stop and report if it misbehaves seriously); intent pattern (`VehicleIntent`, `VehicleInputSource`), tunables in a `VehicleDefinition`, a `VehicleVisual` interface with a placeholder (box body, four cylinder wheels); brake reverses at (near) standstill; interaction area and button (E); exit only at a safe speed beside the left door, else the other side, else refused; separate on-foot and vehicle HUD groups; vehicle camera profile; a spawn in `MapDefinition` on a flat, wide Karaköy street away from the bridge (map scene, GLB, import unchanged); reset after falling or flipping, with the driver; a second test vehicle type to show extensibility; no real model, sound, damage, traffic, or barriers. Implementation and verification: `PROJECT_STATE.md`.

### Phase 4 — Mobile optimization and platform validation

- Use a mobile renderer suited to the Godot version; avoid expensive shadows; review texture, material, map-size, and collision costs; avoid needless per-frame work.
- UI adapts to different phone screens and respects the safe area, notches, and screen edges. Touch buttons are comfortably large.
- Target 60 FPS. A 30 FPS mode for weaker Android devices may be considered. Neither target counts as met until measured on real devices.
- Review iOS and Android export configuration. Isolate device and platform dependencies.

### Phase 5 — Extensibility

Validate the infrastructure for adding a new map, a new vehicle, and NPCs.

Detailed task of 2026-10-28 (user): a map registry with the active map chosen from it (İstanbul • Haliç by default, also in release; `--map=<id>` and a debug overlay switch) and a clean rebuild of player, vehicles, NPCs, camera, and occluders on a switch (checked by node counts); a small second map from Godot primitives with its own spawn, bounds, kill height, vehicle spawns, NPC routes, and viewpoints; the second vehicle type in the game; an NPC that patrols 2–3 points and plays a short hit reaction when punched, preferably on the player's controller with an AI input source, tracked by `WorldManager` (kill height, bounds, respawn at its own start), 2 on İstanbul and 3 on the test map; no damage, health, death, attack, or pursuit; every change to the core systems listed as an extensibility finding; the device scenario extended to the new content on both devices; three-run release measurements with the NPCs (iPhone high: average ≥ 59.5 and long frames < 1 % at three viewpoints; Tab A7 low: average ≥ 29.9 and 1 % low at most 1 FPS below the Phase 4b medians), the physics cost per NPC, and one viewpoint on the test map; the iPhone two-orientation check. Implementation and results: `PROJECT_STATE.md`, "Phase 5".

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

### D15 — Phase 2 rules approved (2026-10-25, user decision)

- **Decision:** The agent-chosen Phase 2 rules (T18) are approved as they are: the punch startup cannot be cancelled, rolls do not chain, a pending roll wins over a pending punch, punch timings 0.10 / 0.10 / 0.25 s, the body stops while punching. Open questions 25 and 26 are closed by this.

### D16 — Phase 3 scope (2026-10-25, user decision)

- **Decision:** Placeholder vehicle (box body, four cylinder wheels) behind a separate visual interface so a model can be swapped in later. The physics engine setting is not changed in this task; the active engine is identified first and the vehicle uses `VehicleBody3D` on it. A switch of engine is the user's decision.

### D17 — Measurement repeats (2026-10-25, user decision)

- **Decision:** From Phase 3 on, every device and viewpoint is measured in at least three runs and reported as the median (with all run values). Protocol: `docs/ARCHITECTURE.md`, "Measurement protocol and host scripts".
- **Rationale:** Single runs of the same build differed by 2–3 FPS in the tablet's 1 % low (Phase 2 regression).

### D18 — Phase 3 driving settings approved (2026-10-26, user decision)

- **Decision:** The agent-chosen vehicle tuning (speeds, steering ramp, brake strength, hill hold; T24–T26) needs no change. Open question 27 is closed by this.

### D19 — Release Perf measurement builds (2026-10-26, user decision)

- **Decision:** Phase 4a measures release builds for local testing only. Android: the release-template APK is signed with the existing debug keystore. iOS: the Xcode Release configuration with the existing development signing (automatic, without `-allowProvisioningUpdates`). Nothing is uploaded anywhere; no release keystore is created. Jolt Physics may be tried for measurement only, in a separate build. Defaults (physics engine, tick rate, quality profiles, renderer, frame limiting) do not change in this task; findings go to the user as proposals.
- **Implementation:** `perf_bench` custom feature only in the "* Release Perf*" presets (`docs/ARCHITECTURE.md`, "Build features").

### D20 — Phase 4 proposals P1 and P2 approved and applied (2026-10-26, user decision)

- **Decision:** P1: every iOS build runs the display at 60 Hz (`display/window/ios/allow_high_refresh_rate = false` in `project.godot`); the high profile keeps its 60 FPS cap. P2: a vehicle with no driver that is at rest is put to sleep (or frozen) and wakes when needed. P3–P8 are not applied: the physics engine (GodotPhysics3D), the 60 Hz physics tick, physics interpolation, and the tablet's frame cap stay as they are; the map, the map pipeline, and the quality profile values do not change.
- **Implementation (Phase 4b):** P1 as above; the measurement-only "iOS Release Perf 60Hz" preset and its `perf_60hz` override were removed because they would now build the same app. P2 uses `RigidBody3D.sleeping` rather than `freeze` (measured: same cost reduction, but a sleeping body is woken by the engine on contact while a frozen one is an immovable wall); rules in `docs/ARCHITECTURE.md`, "Parked vehicles sleep". Results: `PROJECT_STATE.md`, "Phase 4b".
- **P2 criterion accepted (2026-10-27, user via reviewer):** the tablet's physics step fell by 0.75 / 0.86 / 0.79 ms against the ≥ 0.8 ms criterion; this is within the measurement noise, and P2 counts as accepted.

### D21 — Phase 5 scope (2026-10-28, user decision)

- **Decision:** the second map is a small test map built only from Godot primitives and existing materials (no external assets); the NPC patrols 2–3 points and plays a short hit reaction when punched, with no damage, health, death, attack, or pursuit; the test fixture van may become the game's second vehicle type with a placeholder visual; 2 NPCs on İstanbul, 3 on the test map. İstanbul • Haliç (GLB and scene), the quality profile values, the physics settings, and Phase 1–4 behaviour do not change. Device items count only with a log, a results file, or a screenshot.
- **Implementation:** T34–T38; results in `PROJECT_STATE.md`, "Phase 5".

### D22 — Rights to the İstanbul • Haliç package; its generator in the repository (2026-11-01, user decision)

- **Statement (user):** the user produced the İstanbul • Haliç package (the map, the Blender file, and the generation scripts) and holds the rights to it.
- **Decision:** the generation scripts and their input data are kept in the repository (T39); the `.blend`, the previews, the package's Godot demo, and the GLB are not (D6). In the task that brought them in, the map, `assets/istanbul_halic.glb`, the game code, the profiles, and the measurement baselines stayed unchanged, and a regenerated GLB does not replace the current one.
- **Data licences still apply:** geographic data © OpenStreetMap contributors under ODbL 1.0; terrain from Mapzen/Tilezen Terrain Tiles with the USGS, EU-DEM, and ETOPO1 attributions (`docs/maps/istanbul_halic/KAYNAKLAR.md`). The package's `KAYNAKLAR.md` also offers the scripts and the original decor geometry under CC0 1.0, without changing the data terms.
- **Open:** how ODbL's share-alike terms apply to a published build (open question 38); to be settled before any store release.

### D23 — Regenerated maps under their own id, generated on each machine; OSM password tags removed (2026-11-01, user decision)

- **Separate id (open question 39):** a map regenerated from improved scripts joins the registry under its own id; the first is the cells map `istanbul_halic_cells` (T40). İstanbul • Haliç (`assets/istanbul_halic.glb`) stays the default and unchanged, and the new map is loaded only with `--map`, an experiment's `"map"` key, or the debug MAP button (debug and Release Perf builds).
- **Large outputs (open question 40):** generated on each machine from the pinned generator and kept out of Git (`assets/istanbul_halic_cells.glb` in `.gitignore`); the generating command and the expected SHA-256 are recorded in the repository (`docs/maps/istanbul_halic/README.md`, "The cells map"; the integration test checks the hash). Without the file the map's tests report SKIP.
- **Input cleaning:** the `internet_access:password` tag of OSM node 4924038719 (and any other `*:password` tag; there was none) is removed from `maps/istanbul_halic/source/istanbul_extended_v4.osm`; the same node's `description`, which held the same password, was removed with it. The generator's output had to stay byte-identical (it did, `68237c46…`). The tags remain in the Git history of `3d4bb1a` (rewriting history is not authorized; the data is public OSM data).
- **Unchanged:** the quality profile values, the game's behaviour, and the current map.

### D24 — Lighter facades only on experimental maps; no new default yet (2026-11-01, user decision)

- **Open question 41:** `istanbul_halic_cells` does not become the default for now; the question is taken up again with the lighter-facade results.
- **Facade look:** a changed facade look is accepted only on new, experimental map ids (`istanbul_halic_cells_light`, `istanbul_halic_cells_shader`, T41–T42); `istanbul_halic` and `istanbul_halic_cells` stay unchanged.
- **Choice:** the user chooses a variant after the task from the side-by-side shots (`docs/perf/facade/`, open question 42); in this task no variant becomes the default.
- **Unchanged:** the quality profile values, the game's behaviour, and the physics.

### D25 — The shader facade is the chosen variant; criteria for making it the default (2026-11-01, user decision)

- **Choice (open question 42):** after the side-by-side comparison (`docs/perf/facade/`) the user chose the shader facade (`istanbul_halic_cells_shader`, T42). The light facade (`istanbul_halic_cells_light`, T41) stays in the registry as an experimental map.
- **Criteria for the default (user):** (1) Galaxy Tab A7, low profile, shader map: long frames ≤ 1 % in every run (3 runs × 3 viewpoints); (2) iPhone 13 Pro, high profile: average ≥ 59.5, long frames < 1 %, a 10-minute session with thermal state ≤ Fair; (3) the `vehicle_sleep` and `extensibility` device scenarios pass completely on both devices; (4) tablet PSS ≤ 650 MiB, iPhone footprint ≤ 1,000 MiB; (5) the user's visual approval of the distant-window adjustment.
- **Rule:** when 1–4 pass, the shader map becomes the default (first in the registry) in its own commit, so that an ordinary revert undoes it if 5 is not given; İstanbul • Haliç stays selectable. When any of 1–4 fails, the default does not change and the reason is reported.
- **Unchanged:** the quality profile values, the physics, and the gameplay.
- **Result (2026-11-01):** 2, 3, and 4 passed; **1 failed** (one of three runs had 46 and 107 long frames at Spawn and Galata), so **the default did not change**: İstanbul • Haliç stays first. The failure was measured to be a pacing state of single launches on the tablet that also hits İstanbul, the cells map, and the panels without a shader, not the window shader (`PROJECT_STATE.md`, "Shader facade toward the default"); its remedy would change the low profile's frame pacing (open question 43). Criterion 5 is with the user (`docs/perf/facade_v2/`).
- **Update (2026-11-02, user decision):** criterion 1 became relative: on the Galaxy Tab A7's low profile the shader map must not be worse than İstanbul • Haliç measured with the same protocol: (a) at least 9 launches of each, alternating, three viewpoints per launch; (b) the shader map's bad launches (a viewpoint with more than 1 % long frames) at most one more than İstanbul's; (c) its median 1 % low at most 0.5 FPS below İstanbul's at every viewpoint; (d) average FPS ≥ 29.9. Criterion 5: the user delegated the visual decision to the reviewer, and the reviewer approved the footprint filter after looking at `docs/perf/facade_v2/far_windows_high.jpg` and the pan GIFs ("kullanıcı görsel kararı reviewer'a devretti; reviewer onayladı"). Criteria 2–4 passed on 2026-11-01 and were not measured again. The tablet's frame pacing settings do not change (open question 43 is only recorded).
- **Result (2026-11-02):** the relative criterion passed: nine launches of each, one bad launch each, median 1 % low +0.03 / −0.03 / +0.19 FPS against İstanbul at Spawn / Karaköy / Galata, average 30.00–30.01 FPS (`docs/perf/default_map/`). With criteria 2–5 met, **the shader map became the default** in its own commit (`b80c205`): first in the registry, so normal release builds start on it; İstanbul • Haliç, the test district, the cells map, and the light map stay selectable. `git revert b80c205` undoes it alone (the registry order, the experiments pinned to İstanbul, the tests that follow the default; `git apply -R --check` of that commit passed on the final HEAD; the revert itself was not applied). Where the shader GLB is missing (a fresh clone) the game starts on the first available map with a warning (`edadb59`).

### D26 — The project is a map infrastructure (2026-11-02, user decision)

- **Decision:** any GLB that follows the map contract becomes playable without hand work (walk, punch, roll, drive, NPC patrol, quality profiles); for one that does not, the import tool names what is missing and how to fix it, and fixes what it can. Later tasks (streaming included) are designed for maps in general. Written at the top of this file as the main goal.
- **Task of 2026-11-02 (Phase 6a):** the map contract (`docs/MAP_CONTRACT.md`), the render categories moved from `RenderSettings` into each map's data, a general import tool, and the proof on three maps: the user's Safranbolu package (test input only, not added to the game), the shipped `istanbul_halic.glb` under a test id (robustness; it does not replace İstanbul • Haliç), and a CC0 model. The existing maps, the default map, their look and measurements, the quality profile values, the physics, and the gameplay do not change; the İstanbul generator stays as it is. Large test GLBs stay out of Git; a CC0 test map under 10 MB and its licence may be committed.

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

### T24 — Vehicle architecture

- **Decision:** `VehicleController` (on `VehicleBody3D`) reads a `VehicleIntent` from a `VehicleInputSource` each tick; static, testable functions turn it into engine force, per-wheel brakes, and steering (`drive_command`, `steer_angle`, `approach_steer`); all tunables are in a `VehicleDefinition`; `VehicleVisual` gets speed, steering, light state, and wheel poses. A new vehicle type is a scene plus a definition (demonstrated by `tests/fixtures/test_van.tscn`). New physics layer 4 "vehicle".
- **Engine facts the code depends on (GodotPhysics3D, measured):** the body drives along +Z (vehicles face +Z, `get_follow_yaw()` gives cameras the yaw behind them, `place_at()` converts the −Z convention of map transforms); positive steering turns left (negated); default linear damping 0.1 capped speed near 15 m/s (replaced by `linear_damp` 0); 8° steering at 21 m/s rolled the car (5° at top speed does not).
- **Rationale:** Same pattern as the player (T3), so AI drivers and other vehicles need no controller changes.

### T25 — Vehicle controls layout

- **Decision:** Steering with two hold buttons on the left (◀ ▶), smoothed into an analog value by `steer_rate` / `steer_return_rate`; throttle (160), brake/reverse (140), and handbrake "P" (116) as hold buttons bottom right; exit (116) top right, away from the pedals. Keyboard W/S/A/D, Space handbrake, E get in / out. On-foot and vehicle controls are separate groups; `set_vehicle_mode()` shows one and releases every finger and pending press; punch and roll presses are ignored while driving.
- **Why buttons rather than a horizontal drag:** buttons work without looking and without a drag origin that drifts under the thumb, keep the existing button routing and finger ownership (T2) unchanged, behave like the keyboard (same intent values), and are easy to test. Analog feel comes from the steering ramp; the drawback is no fine partial steering by thumb position. A drag or tilt option can be added as another `VehicleInputSource` later.

### T26 — Getting in and out

- **Decision:** `VehicleInteraction` owns the handover: interact button only with a vehicle in reach and the player on a floor; entering seats the player (`set_seated`: hidden, collision off, physics off, actions and presses dropped), swaps HUD group, input source, and camera profile; the world stops tracking the hidden player. Exiting: speed ≤ `safe_exit_speed` (1.5 m/s), then the exit markers in order (driver's side, then passenger side) with a floor ray and a capsule overlap query; otherwise refused and the press dropped; the exit button fades while too fast. Focus loss or pause: buttons and actions released, throttle dropped, handbrake held until a pedal is pressed. With no pedal below `hold_speed` (0.5 m/s) the brakes hold the car on slopes (added after it rolled back on a steep Karaköy street).

### T27 — Vehicle placement and reset

- **Decision:** `MapDefinition.vehicle_spawns` (transforms facing −Z, like the player spawn); İstanbul • Haliç: (−88.96, 14.7, 36.14) facing 75°, a Karaköy street found by collider queries (70 m × 6 m free corridor on `Ground_*`, ≤ 1.1 % grade, buildings on both sides, ~87 m from the bridge axis). Reset to the spawn below the map's kill height, or after 2 s flipped beyond 70° while nearly still; the seated driver goes along.

### T28 — Vehicle camera

- **Decision:** `vehicle_camera_profile.tres` (7.5 m, pivot 1.9 m, pitch −14°) with the new follow mode: after 1 s without look input the yaw swings back behind the vehicle (`follow_yaw_sharpness` 2.5). The optional speed-dependent distance was not implemented.

### T29 — Screen layouts and safe areas (Phase 4c)

- **Decision:** The HUD reads the safe area through an injectable `SafeAreaSource` (default `DisplayServer`, so devices are unchanged), re-applies it when it changes without a size change (checked every 0.25 s; a 180° turn moves a cutout or navigation bar), and releases every finger on such a change, as on focus loss. A headless matrix of nine screens (16:9, iPhone notch left/right, 20:9 punch-hole with a 3-button bar or gesture handle on either side, 4:3 iPad, 16:10 Tab A7) checks both control groups for: safe area, hit areas apart, joystick and camera drag zones clear of buttons, debug overlay clear, and touch targets of at least 7 mm (hit area, from the screen's ppi). Reference shots per screen in `docs/ui/`.
- **Result:** every combination passed without a layout change (gameplay targets 9.6–21.6 mm, gaps of at least 18 canvas units), so the button layout of T22/T25 stays. The Android insets and ppi values are assumed typical values; no Android phone was available (user, 2026-10-27).
- **Rationale:** the canvas is 900 units tall on every landscape screen wider than 16:10 and the controls anchor to the safe area's corners, so phones only gain width; the checks pin that down for the screens the game may meet before more devices are available.

### T30 — The player wakes a parked car only while pushing (Phase 4c)

- **Decision:** `PlayerController` wakes bodies it touches only while its intent moves. Found in the Phase 4b on-device check on the iPhone: the idle player standing against a car on a sloped street kept a wall contact, and that kept the car awake. Test: `test_standing_against_a_parked_car_on_a_slope_lets_it_sleep` (fails without the change).

### T31 — Platform module (Phase 4d)

- **Decision:** `Platform` (`game/platform/platform.gd`) is the only code that reads OS feature tags, the build kind, the window and safe area, the screen refresh rate, and the external Documents folder; its rules (safe area only on mobile, external folder only on Android, iOS pacing at 60 Hz with the setting off) sit on overridable raw sources. `QualityProfiles`, `SafeAreaSource`, `PerfConfig`, `BuildFeatures`, `PerfBenchmark`, and `game.gd` use it; behaviour is unchanged (device logs identical, `PROJECT_STATE.md`, "Phase 4d"). Tests install a fake platform; a scan test fails on platform calls anywhere else in `game/`.
- **Rationale:** the iOS and Android paths could only be exercised on devices; now each runs in a desktop test, and new platform decisions have one place to go.

### T32 — Export configuration (Phase 4d)

- **Decision:** the version name has one source, `application/config/version` (0.1.0); preset name fields stay empty. The build number is the same in every preset (1). Android stays on the template build (no Gradle): its minSdk 24 / targetSdk 36 come from the Godot 4.7.2 template. iOS keeps Godot's default deployment target 15.0 and the export's generated privacy manifest. No permissions, capabilities, usage descriptions, or tracking anywhere. `test_export_presets.gd` pins the reviewed values.
- **Consequences recorded:** the Mobile renderer makes the iOS app require an A12 or newer device (`iphone-ipad-minimum-performance-a12`, added by the exporter); Android needs API 24 or newer.

### T33 — Automatic on-device checks (Phase 4d)

- **Decision:** checks that can be scripted run as a `DeviceScenario` in a debug build (synthetic touches, `SCENARIO` log lines, a results file); the host turns Android devices with adb (`android_rotate_on_cue.sh`, which restores the rotation settings). Only steps that need a hand (turning an iPhone) are asked of the user, and they count only with evidence (gravity sensor values, screenshots, logs). The gravity sensor is enabled in debug builds only, for that evidence.
- **Rationale:** in Phases 4b–4c several user answers were not borne out by logs or screenshots; scripted checks give evidence without depending on that.

### T34 — Map registry and runtime map switch (Phase 5)

- **Decision:** the loadable maps are a `MapRegistry` resource (`game/world/maps.tres`) of `MapDefinition`s with an `id`; the first is the default and the only map a normal release build loads. Debug and Release Perf builds pick another with an experiment's `"map"` key or `--map=<id>`; debug builds cycle with a MAP overlay button. `Main.switch_map()` frees the old map with its vehicles, NPCs, and the training dummy, restores the render defaults before the new map's `RenderSettings` captures them, and re-applies the profile; it is refused while driving.
- **Rationale:** the task asked for selection from a registry, a command-line override, an overlay switch, and an unchanged release default. Refusing the switch while driving avoids a forced exit path in `VehicleInteraction` (no core change); a map switch is a debug tool for now.
- **2026-11-02:** the default is the first available map (T44), the shader facade map first in the registry (D25).

### T35 — NPCs on the player's controller (Phase 5)

- **Decision:** an NPC is `game/npc/npc.tscn`, a scene inherited from `player.tscn`, with the root script `Npc extends PlayerController` (wiring only), an `AiPatrolInput`, a `Hurtbox`, a new `HitReactionState`, its own colour, and physics layer 5 "npc". `PlayerController` and the existing states are unchanged. One NPC per `PatrolRoute` in `MapDefinition.npc_routes`; `WorldManager` places, tracks (own respawn point), and frees them.
- **User decisions applied (task of 2026-10-28):** patrol between 2–3 points, a short hit reaction, then the patrol continues; no damage, health, death, attack, or pursuit; 2 NPCs on İstanbul and 3 on the test district.
- **Physics:** the player and NPCs block each other (the player's mask now includes layer 5); the camera ignores NPCs; vehicles still pass through characters (as with the player, T24).
- **Level of detail ("far mode"):** farther than 10 m from the player (back within 8 m) an NPC leaves the controller and a Tween moves it along its route, with floor rays once per segment. Measured on the Galaxy Tab A7 (`PROJECT_STATE.md`, "Phase 5"): two walking NPCs under the controller added 2.3–2.9 ms to the physics step (1.1–1.4 ms each in the three-run A/B) and lowered the 1 % low by about 2 FPS, which failed the task's criterion in a probe; on the Mac a character's cost is about the same on boxes and on trimesh, so it is mostly script and transform work, not collision. A far walk scripted every tick still cost about 0.6–0.75 ms per NPC; the Tween walk costs 0.27–0.32 ms per NPC (three-run A/B), and with it the measurement criteria were met. Far NPCs ignore collisions, so routes must be clear.
- **Rationale:** reusing the controller is what the specification's T3 promised and what the task asked first; the far mode keeps that promise where it matters (near the player, where NPCs can be touched or punched) while keeping the tablet's frame budget.

### T36 — AI input source (Phase 5)

- **Decision:** `AiPatrolInput` (`PlayerInputSource`) walks at half walking speed toward the current point, waits the route's `wait_seconds`, loops, and gives a point up after 2 s of walking without getting 0.25 m closer. It reads only its own body; it never runs, punches, or rolls.
- **Rationale:** the intent pattern (T3) needed no change; the stuck rule covers walls, cars, other NPCs, and the player standing in the way (the task's "takılma kurtarma").

### T37 — Test district (Phase 5)

- **Decision:** a 120 m square map of Godot primitives (box buildings, two streets, a 9.5° ramp to a raised plaza, walls, İstanbul's sky and sun), generated by `tools/build_test_district.gd`, with box and convex colliders and one box occluder per building. Its tests need no GLB.
- **Rationale:** the user chose a small primitive test map; generating it keeps the layout reproducible. Headless on the Mac an NPC costs about the same on its boxes as on İstanbul's trimesh bridge (0.29 vs 0.32 ms per step).

### T38 — Second vehicle type in the game (Phase 5)

- **Decision:** the test fixture van became game content (`placeholder_van.tscn`, `definitions/van.tres`); `MapDefinition.vehicle_scenes` gives a vehicle type per spawn (`Main.vehicle_scene` where empty); the test district parks the compact car and the van. The debug CAR button walks up to each vehicle in turn.

### T39 — İstanbul • Haliç generator in the repository (2026-11-01)

- **Layout:** the scripts in `tools/maps/istanbul_halic/` (beside the other generators, excluded from exports by the presets' `tools/*` filter); the inputs in `maps/istanbul_halic/source/` (the map's folder, inputs only); the files the package's run wrote for the shipped GLB in `maps/istanbul_halic/reference/`, never written by the generator. Both data folders carry a `.gdignore`: the export presets include `maps/`, and without it Godot would import the elevation PNGs and pack the 19 MB OSM extract and the JSON records into every build.
- **Paths:** the scripts were first committed byte-identical to the package (`3d4bb1a`), then changed only in their paths: `--source` (only read) and `--out` (default `build/maps/istanbul_halic/`, ignored by Git; refused inside `--source`); `street_details.py` reads the `vegetation.json` that the same run wrote to `--out`. `render_map.py` (Blender) takes the same `--out`. No geometry code changed.
- **Environment:** Python 3.12 (3.12.15 verified) with `requirements.txt` pinned (numpy 2.5.4, shapely 2.1.2 with GEOS 3.13.1, mapbox_earcut 2.1.0, pillow 13.0.0); the virtual environment lives outside the repository. shapely 2.1.2 was chosen because, of the three versions tried, it reproduces the shipped GLB most closely; GEOS decides the road and pavement triangulation and, through `STRtree.nearest` ties, where a few signal poles stand. Results: `PROJECT_STATE.md`, "Map generator in the repository".
- **Rationale:** open question 20 asked for the scripts in the repository so map-level work can be reproduced and reviewed; keeping the original commit separate shows every later change to the generator as a diff against the package.

### T40 — Facade detail and vegetation in 40 m cells; the cells map (2026-11-01)

- **Grouping:** `build_map.py --detail-cell METRES` meshes `Detail_*`, `Trees_*`, and `Shrubs_*` per cell inside each 150 m chunk (`<Category>_<cx>_<cy>_<i>_<j>`), each building, tree, or shrub whole in the cell of its centre; no triangle changes, and `compare_outputs.py --grouped` proves it (the cells of each chunk hold exactly its triangles; everything else byte-identical). Off by default, so the pinned output stays `68237c46…`.
- **Not regrouped, although the task listed them:** `MosqueDetail_*` and `LandmarkDetail_*` are already one mesh per mosque or landmark (125 + 1), finer than any cell; merging them into cells would make them coarser. `TreeTrunks_*` are `-col` meshes (184 of the 827 static bodies): regrouping them would change the collision, which the task fixed; so the trunks stay in 150 m chunks while the crowns move to cells, and on the low profile a trunk chunk can be hidden under a visible crown (seen in no benchmark screenshot; it disappears once trunks get their own colliders, the simple-collider task).
- **Cell size 40 m** (75 m compared; `PROJECT_STATE.md`, "Cell grouping and the cells map"): both remove the blank facades seen at the three viewpoints and leave no nearby building (within 50 m) blank on the low profile; within 100 m 40 m leaves 8.7 % of the buildings blank against 18.0 % for 75 m (34.6 % with 150 m chunks), and on the high profile it draws the fewest primitives at the street viewpoints (Galata 101 k against 150 k and 323 k on the Mac). It costs more meshes (6,129 against 3,925 and 3,055), more draw calls than the chunks (on the Mac 1–4 more on the low profile, 10–20 on the high; 75 m: 1–3 and 4–9), and memory: about +185 MiB video memory and +64 MiB static memory on the Mac (75 m: +15 and +18 MiB), +280 MiB footprint on the iPhone. The blank facades within 100 m are what D12 named as the visual cost of the low profile, so the size that removes most of them was chosen; 75 m is the fallback if memory decides.
- **Own map, own occluders:** a separate id (D23) with the same data as İstanbul • Haliç. The occluders are baked from the cells map's collision (643 occluders, 317,518 triangles) instead of sharing İstanbul's file: the regenerated Atatürk bridge piers stand 2.7–3.5 m from the shipped ones (`PROJECT_STATE.md`), and an occluder where no pier is would hide what stands behind it.
- **Availability:** `MapDefinition.required_files` lists files generated on each machine; while one cannot be loaded (its import result is missing), the MAP button skips the map and `--map` falls back to the first map with a warning. Needed because the GLB is not in Git (D23) and the MAP button would otherwise load a missing scene; one of the extensibility findings of the task (`PROJECT_STATE.md`).
- **Import settings:** `assets/istanbul_halic_cells.glb.import` is committed with the shipped GLB's values; Godot 4.7.2 would otherwise write `gltf/naming_version=2` and `gltf/texture_map_mode=1` for a new file.

### T41 — Light facade: the same windows with half the triangles (2026-11-01)

- **Method** (`build_map.py --facade light`): every window keeps its surround and glass quads (51.6 % of the facade triangles in the full facade); the mullions and sills (30.6 %) are dropped; windows whose point 1 m in front of the wall lies inside another building with a higher roof (24.0 % of the windows) are dropped, and cornices and string courses hidden at a quarter, half, and three quarters of their wall; balcony railings are flat bars (2 triangles instead of 12). Windows and bands are emitted after the building loop, when every roof height is known; the loop's RNG calls stay, so no other mesh changes.
- **Result:** `Detail_*` 4,187,598 → 2,092,604 triangles (−50.03 %), GLB 506 → 363 MB, imported scene 201 → 144 MB; every other mesh byte-identical (`compare_outputs.py --facade`). Analysis and measurements: `PROJECT_STATE.md`, "Lighter facades".
- **Rationale:** of the "near the same look" options only hidden-window culling is free of visible loss; the other half had to come from the smallest visible parts (mullions, sills). The 1 m distance keeps windows that can be seen down a walkable gap (the player's capsule is 0.7 m wide).

### T42 — Shader facade: one panel per wall and a window shader (2026-11-01)

- **Method** (`build_map.py --facade shader`): instead of the cornice, string courses, and windows each wall of 2.8 m or more gets one panel 3 cm in front of it, with UV (metres along the wall and above its ground line), UV2 (column width, wall height), the wall colour, and a per-wall seed in the colour alpha, on a new seventh material `Istanbul_FacadeWindows` (appended, so the other meshes keep theirs). Roofs, doors, awnings, chimneys, and roof boxes stay geometry; balconies get the light railings. The shader map's script draws those surfaces with `maps/istanbul_halic_cells_shader/facade_windows.gdshader`, which repeats the full facade's layout (surround, 88/12 % glass tints by a hash, a mullion in every other column, cornice, string courses), box-filters edges over one pixel, and fades the pattern to its average colour beyond about 0.35–0.9 m of wall per pixel.
- **Result:** `Detail_*` 4,187,598 → 324,120 triangles (−92.26 %), GLB 255 MB, imported scene 102 MB; every other mesh byte-identical.
- **Rationale:** the walls are in the `Buildings_*-col` collision meshes, which had to stay byte-identical, so the shader cannot sit on the wall itself; a panel in the facade detail keeps the profiles' visibility ranges and the cells unchanged. The look loses relief (no projecting surround, glass, cornice) and the generator's exact glass tints.

### T43 — Distant windows by filtering over the pixel footprint (2026-11-01)

- **Decision:** `facade_windows.gdshader` box-filters each element (surround, glass, mullion, cornice, string course) over the pixel's footprint on the wall (`fwidth(UV)`, uniform `filter_pixels` = 1): the exact share of the pixel each covers, from the integral of its periodic pattern, with the glass tint going to its average where a pixel spans several windows. It replaces the first version's fade to the average colour beyond 0.35–0.9 m of wall per pixel. One shader for every profile; the GLB and the panels are unchanged.
- **Rationale:** the user asked for distant windows closer to the full facade without shimmering in motion (D25, criterion 5). A box filter keeps a window's full contrast while it is a pixel or more wide and converges to the same average as it shrinks, so no distance threshold has to be tuned per resolution (the first version's fade started at about 120 m at 960×540 and about 250 m at 1920×1080). Measured on the Mac: the distant windows look like the cells map's up to the 200 m range, and in a half-pixel-per-frame pan the filter has the lowest ratio of temporal second difference to change of the three (cells 1.46–1.51, first version 1.34–1.46, filter 1.28–1.44; `docs/perf/facade_v2/`). The tablet A/B (on the first version) found no long-frame or GPU-time difference between the panels with the window shader, a simplified shader, and the plain wall colour, and the filter's device measurements kept the first version's frame rates (iPhone 60.00 FPS, tablet 30.00 FPS), so the shader needs no cheaper low-profile path.

### T44 — The default is the first available map (2026-11-02)

- **Decision:** `MapRegistry.default_map()` is the first map whose `required_files` can all be loaded; `Main._initial_map()` uses it when no map is requested, and when `--map` or an experiment names an unknown or unavailable map, with a warning that names the missing files. The same rule holds in normal release builds. With no available map the game logs an error that names each map's missing files and shows "Harita yüklenemedi: harita dosyaları eksik." on the loading screen instead of loading. İstanbul • Haliç lists its GLB in `required_files` too (copied in, out of Git, D6).
- **Rationale:** the default map's GLB is generated on each machine (D23), so a fresh clone lacks it; the game should still start (on İstanbul where its GLB is copied in, else on the test district, which needs no file) and say why, rather than fail to load a missing scene. A release package that leaves out the default map's GLB gets the same visible fallback or a clear error (open question 36).

### T45 — Render categories are map data (2026-11-02, Phase 6a)

- **Decision:** the category vocabulary (`CategoryRules.CATEGORIES`: facade_detail, decor, lamps, trees, buildings, ground, water) stays the game's, because the quality profiles and experiments name it; the rules that put a map's meshes into it move into the map (`MapDefinition.category_rules`, a `CategoryRules` resource of ordered `CategoryRule`s: prefix, regex, words, material, group; a default category; the occluder categories). `RenderSettings` lost its built-in İstanbul prefix table, its occluder category list, and its fog colour constant: the depth fog now fades to the map's procedural sky horizon colour, which on every existing map is exactly the old constant.
- **Proof:** all 21,458 mesh assignments of the five maps byte-identical before and after (a dump from the old code at `cbaf661` and from the new rules), `test_map_categories_unchanged.gd` against the old table, the default map's Mac benchmark (low and high, three viewpoints) with the same draw calls, primitives, and objects (`PROJECT_STATE.md`, "Phase 6a").
- **Rationale:** D26: a map that is not İstanbul must be able to say what its meshes are without code changes. One of the extensibility findings of Phase 6a (a core change).

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

## Phase 4 proposals (measured 2026-10-26; P1 and P2 applied in Phase 4b)

Each proposal comes from the Phase 4a measurements (`PROJECT_STATE.md`, "Phase 4a"). P1 and P2 were approved and applied (D20); P3–P8 are not applied.

| # | Proposal | Measured gain | Risk / behaviour change |
|---|---|---|---|
| P1 | **Applied (D20).** iPhone: display at 60 Hz (`allow_high_refresh_rate = false`), keep `max_fps` 60 | 1 % low 41.9 → 55.4–55.5; long frames 49.5 % → ~0; average and thermal unchanged | None for gameplay; no 120 Hz option (high is capped at 60 anyway). Affects all ProMotion iPhones. |
| P2 | **Applied (D20)** as sleep. Parked vehicles: freeze or let sleep when nobody drives and they are at rest | Upper bound ≈ 1.0 ms per physics step on the tablet (≈ 2 ms per frame at 30 FPS); not measured on the iPhone. **Phase 4b result:** −0.75 / −0.86 / −0.79 ms on foot against Phase 4a (criterion ≥ 0.8 ms missed at two viewpoints); same-session A/B 0.35–0.81 ms; iPhone −0.17 to −0.44 ms | Must wake for getting in, resets, and the hill hold; the interaction area must keep working. |
| P3 | Player: skip `move_and_slide` while standing still on a floor | Upper bound ≈ 0.85–1.15 ms per step on the tablet (only while idle) | Floor snapping and respawn edge cases; little gain while moving. Low priority. |
| P4 | Physics at 30 Hz on the tablet | One step per frame instead of two (≈ 5 ms per frame); 1 % low +0.8 to +2.0 | The car becomes unstable (58.7 m/s, rollover) and the punch lasts 0.5 s; would need vehicle substepping or retuning. Not recommended now. |
| P5 | Jolt Physics | None: ~2 ms per step slower on the tablet | Not recommended (open question 8). |
| P6 | Switch map colliders off far from the player (streaming) | ≈ 0.2–0.7 ms per step | Needs a runtime activation scheme; colliders are large chunks. Low priority. |
| P7 | Physics interpolation off | ≤ 0.3 ms per step | Visible stutter at 120 Hz and with the camera; not recommended. |
| P8 | Tablet frame cap: keep `Engine.max_fps` 30 with Swappy | — (uncapped averages 37–40 FPS but alternates 16.7 / 33.3 ms frames) | Keep as is. |

Order suggested: P1, then P2, then re-measure (done in Phase 4b); P3 and P6 only if the tablet still needs margin.

## Before a store release (checklist; nothing of this is created yet)

Written in Phase 4d (2026-10-28). The measurement and debug presets are not release presets; a normal release preset per platform would need, in this order:

1. **Identity:** the new Apple Developer account and its Team ID (D8: update `application/app_store_team_id`), the final bundle ID `com.mirongi.mapsimulator` registered there and only there, an App Store Connect app record; on Android a Play Console app for `com.mirongi.mapsimulator`.
2. **Signing:** an Android release keystore created and backed up outside the repository, passed at export time through `GODOT_ANDROID_KEYSTORE_RELEASE_*` as the Release Perf builds already do (D10; never in `export_presets.cfg`); Play App Signing enrolment; on iOS an "Apple Distribution" identity and an App Store provisioning profile (`application/export_method_release` = App Store), still without `-allowProvisioningUpdates` unless the user decides otherwise (D9).
3. **Versioning:** raise `application/config/version` for each release and the build number in every preset together (Android `version/code`, iOS `application/version`); the stores reject a repeated build number.
4. **Build format:** Google Play takes an Android App Bundle (AAB), which needs the Gradle build (`gradle_build/use_gradle_build`, `gradle_build/export_format` = AAB) and the Android build template installed in the project; that also makes `gradle_build/min_sdk` / `target_sdk` settable. Target API: Google Play requires API 36 for new apps and updates since 31 August 2026 (https://developer.android.com/google/play/requirements/target-sdk); the template already targets 36. iOS: an archive and upload from Xcode or `xcodebuild -exportArchive`.
5. **Privacy:** Apple: "Starting May 1, 2024, apps that don't describe their use of required reason API in their privacy manifest file aren't accepted by App Store Connect" (https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api). Godot 4.7.2 writes `PrivacyInfo.xcprivacy` from the preset's `privacy/*` options (template `misc/dist/apple_embedded_xcode/PrivacyInfo.xcprivacy`, defaults in `editor/export/editor_export_platform_apple_embedded.cpp`): file timestamp DDA9.1 + C617.1, system boot time 35F9.1, disk space E174.1 + 85F4.1, no user defaults (none used by Godot's Apple platform code), tracking off, no collected data. Still open for a store build: the App Store Connect privacy labels; a check that every bundled framework (for example MoltenVK) carries its own manifest where Apple requires it (Apple: "For each executable or dynamic library … the bundle … needs to include a privacy manifest file"); and re-checking the reasons if plugins or networking are added. Google Play: the Data safety form; a privacy policy URL.
6. **Store assets and metadata:** final app name and icon (open question 5), all icon sizes the stores need, a launch screen, screenshots per device class, age rating, export compliance (the iOS build already declares `ITSAppUsesNonExemptEncryption` = false).
7. **Release builds:** the quality profiles and the game are not debug-only, but `BuildFeatures` hides the debug overlay and experiments only when neither debug nor `perf_bench`: a release preset must carry no `perf_bench` (pinned by `test_build_features.gd`).

## After the specification (options; nothing started)

Phases 0–5 of the specification are implemented (`PROJECT_STATE.md`, "Specification status"). The three candidate directions, each needing a user decision:

| Option | Prerequisites | Expected effect (from measurements where there are any) | Risk |
|---|---|---|---|
| Map-level facades and simple colliders | The user's approval to change the map pipeline and the decisions in open questions 21 and 30; the generation scripts are in the repository and reproduce the current map (T39, 2026-11-01); smaller cells are done as the separate cells map (T40, D23), lighter facades as two experimental maps (T41, T42, D24), of which the shader facade is chosen (D25) and the default since 2026-11-02 | Facade detail is 64.2 % of the 7.07 M triangles: lighter facades in smaller cells would let the tablet's low profile drop fog, the 0.6 render scale, or the blank nearby facades (D12). Simple colliders instead of 827 trimesh bodies: the player's physics tick costs ~1 ms per step on the tablet (Phase 4a), but Phase 5 found a character's cost to be mostly script and transform work (on the Mac an NPC costs 0.29 ms per step on boxes and 0.32 ms on trimesh), so the physics gain of simple colliders is likely small; not measured on the tablet | High: regenerates the map, occluders, colliders, and every measurement baseline |
| Real character and vehicle models | A character model with idle, walk, run, punch, roll, and hit animations and a car model with four separate wheels, with sources and licences (open questions 1, 2) | Plug-in points exist and are tested: `CharacterVisual` (`play_action` punch / roll / hit for an AnimationTree), `VehicleVisual` (wheel order). Costs to measure: skinned meshes and animation per character (CPU on the tablet, where a character already costs ~1.1–1.4 ms per step, question 34) and draw calls | Medium: art-dependent; performance unknown until measured |
| Store preparation | The new Apple Developer account and Team ID, the final bundle ID registered there, a release keystore, app name and icon (open question 5), privacy labels; the checklist in "Before a store release" | Release presets without `perf_bench`, an Android App Bundle through the Gradle template (target API 36 already), an iOS archive; decide whether the test district ships (question 36) | Low technically; depends on external accounts and assets |

## Planned features

Everything listed under "Requirements by phase" is implemented (Phase 5 completed 2026-10-28); what follows is in "After the specification".

### Streaming loader (defined 2026-11-02 from the measurements of 2026-11-01/02; not started)

- **What:** the default map's 40 m facade cells (`Detail_*`), tree crowns (`Trees_*`), and shrubs (`Shrubs_*`) as separately loadable parts around the player; the terrain, roads, building shells, landmarks, and all collision of the map (or of its 150 m chunks) loaded at start. Parts load on a background thread (`ResourceLoader.load_threaded_request`), enter the scene within a per-frame budget, and are freed behind the player with hysteresis. The loading screen (2026-11-01) stays for the first part set and for map switches, which then load only that set.
- **Why:** on the Galaxy Tab A7 the PSS follows the mesh count: the shader map keeps the cells map's 6,129 meshes and sits at 615 MiB stable PSS against İstanbul's 502 MiB with 3,055 meshes (Release Perf); a load blocks 5.8 s at startup and 6.8–9.5 s per switch (debug) and holds 15–115 MiB of temporary data above the stable PSS (810 MiB peak loading the cells map), while the low-memory killer reclaims other processes.
- **Acceptance, Galaxy Tab A7** (Release Perf, three runs; the debug build for the switch scenario): stable PSS on the default map ≤ 502 MiB (615 today); map ready ≤ 4.0 s (5.8 s today); the peak PSS of a switch ≤ the larger map's stable PSS + 50 MiB (shader → cells 810 against 746 today), with no low-memory reclaim of this app; walking and driving the viewpoints' route, no frame over 50 ms caused by part loading; long frames by D25's relative criterion against today's build; 1 % low within 0.5 FPS of the medians of 2026-11-02 (25.80 / 25.89 / 25.17).
- **Acceptance, iPhone 13 Pro:** footprint ≤ 860 MiB (854–860 today), 60 FPS with 0 long frames, map ready ≤ 1.2 s (1.19 s today).
- **Unchanged:** the look within the profiles' visibility ranges (side-by-side shots), the collision, the tests of every map.

## Agreed but unimplemented functionality

See "Requirements by phase". `PROJECT_STATE.md` records which parts exist.

## Deferred ideas

- 30 FPS mode for weaker Android devices (Phase 4, to be considered).
- Desktop keyboard and mouse controls are allowed only as development aids.

### Deferred map candidate: Safranbolu (audited 2026-10-28, deferred 2026-11-01)

- **What it is:** a 500 m Safranbolu model package produced by the user with its own generation script (kept outside the repository). A read-only audit (no repository changes) found: 929,216 triangles in 1,173 meshes, one object per building; no normals and no colliders in the GLB; double-sided materials; 23.2 % of the road centrelines run inside building footprints (Microsoft footprints beside OSM roads); facade geometry 72.6 % of the triangles.
- **Status:** deferred by the user (2026-11-01) in favour of the İstanbul • Haliç pipeline (D22, T39). Nothing of it is in the repository.
- **If it resumes:** bring its script and inputs in the same way (T39), fix the road–building overlap, generate normals and simple colliders at the source, and add it as a separate map id (T34).

## Rejected alternatives

- **Generating instruction files with `/init`:** rejected by the bootstrap instructions in favor of hand-maintained files.
- **Duplicating the full shared policy in `CLAUDE.md`:** rejected; two copies would drift apart.
- **Storing the map GLB with Git LFS:** declined by the user on 2026-10-24 (quota cost).
- **Working directly in the Google Drive folder:** rejected; it is not under Git and the map original must stay unmodified.

## Open questions

1. Character model and animations: none exist in the map package. Where will they come from? A placeholder is used until then (D14). The `CharacterVisual` interface (T20) is where they plug in.
2. Car model: the map has no vehicles. A placeholder (box body, cylinder wheels) is used (D16); a model plugs in behind `VehicleVisual` with the same wheel order. Source and license still needed.
3. The settings packages are adopted as profiles (D12). Map-level facade work: see question 21.
4. Target device list beyond the two test devices. Does the Galaxy Tab A7 class stay a 30 FPS target given the measured visual cost?
5. App name and final icon; Android release keystore. (Identifiers and debug signing are decided: D8–D10.) Everything a store release needs is listed in "Before a store release"; none of it is created.
6. In-game UI language.
7. Audience and monetization: not specified.
8. Physics engine for vehicles. **Finding (2026-10-25):** the project setting `physics/3d/physics_engine` is `"DEFAULT"`, and in Godot 4.7.2 that runs **GodotPhysics3D**, not Jolt. Evidence: the world's direct space state is a `GodotPhysicsDirectSpaceState3D` and body states are `GodotPhysicsDirectBodyState3D` (in throwaway projects outside the repository, `"Jolt Physics"` gives `JoltPhysicsDirectSpaceState3D` / `JoltPhysicsDirectBodyState3D`, while `"GodotPhysics3D"` and `"DEFAULT"` both give the Godot classes); a space created through `PhysicsServer3D` keeps space parameters that Jolt ignores and is reported at exit as a `GodotSpace3D` allocation; `ClassDB` lists `GodotPhysicsServer3D` and no Jolt server class. Debug builds log it in the `STARTUP` line (`physics_3d=GodotPhysics3D (setting DEFAULT)`), and `test_active_physics_engine_is_detected` fails if it changes. The setting was not changed (user decision); the vehicle uses `VehicleBody3D` on GodotPhysics3D, which showed no serious problem (findings in `PROJECT_STATE.md`, "Phase 3"). **Recommendation:** stay on GodotPhysics3D for now; try Jolt as a measured Phase 4 experiment, because one physics step costs 4.0–5.6 ms on the Galaxy Tab A7 (two per frame at its 30 FPS cap) against 1.0–1.5 ms on the iPhone. A switch needs the user's decision and a re-run of the Phase 1–3 tests and device checks (vehicle tuning in particular: +Z forward, steering sign, damping, and rollover were measured on GodotPhysics3D). **Jolt measurement (2026-10-26, Phase 4a, tablet, release):** one physics step 6.69 / 6.78 / 6.88 ms on foot vs 4.79 / 4.69 / 5.59 ms with GodotPhysics3D (in the vehicle 6.14–6.36 vs 3.54–4.22 ms), 1 % low slightly lower (24.0–24.7 vs 24.9–26.0), map ready 6.9 vs 6.2 s; the headless suite passes with Jolt except the test that pins GodotPhysics3D. **Recommendation now:** keep GodotPhysics3D; Jolt brings no gain for this scene on this device.
9. Whether the original explorer demo (`main.tscn`, `scripts/explorer.gd`, `scripts/main.gd`) should be kept long term.
10. Branch strategy: work currently happens directly on `main`. Decide whether feature branches or pull requests are wanted.
11. Whether `.vscode/` should be committed, ignored, or left untracked. It is currently left untracked.
12. Railings, lamps, and other decor have no collision, so the player can walk off bridge decks and quays into the water (then respawns). Should invisible barriers be added along bridges and quays? **Vehicle observations (2026-10-25):** a car driven across the Galata Bridge deck toward the railing passes through it, falls into the water, and resets to its Karaköy spawn with the driver (reached y −5.1, kill height −5.0); pavements and kerbs have no collision of their own, so cars drive onto pavements freely; lamp posts do not stop a car either. With vehicles, barriers along bridge decks and quays (and possibly kerbs) matter more than on foot; not added (out of scope).
13. Run control style: is the toggle with reset on stick release (T7) what the user wants, or a hold button, or auto-run at full stick tilt?
14. HUD art: the controls are drawn with plain shapes. Is final art or an icon set planned?
15. *(Closed 2026-10-27 by D20: every iOS build runs the display at 60 Hz. Phase 4b measured on the iPhone 13 Pro, release: 1 % low 56.3–58.7 FPS at the three viewpoints on foot and in the vehicle, 0 long frames, the 10-minute session at 60 FPS with thermal Nominal; `PROJECT_STATE.md`, "Phase 4b".)* iPhone frame pacing. **Finding (2026-10-26, Phase 4a):** with the default 120 Hz display (`display/window/ios/allow_high_refresh_rate = true`) and `Engine.max_fps` 60, frames alternate 8.3 / 25 ms (49.5 % of frames one refresh late); the ~41 FPS "1 % low" is these 25 ms frames. With the display at 60 Hz (the same setting off; measured in the "iOS Release Perf 60Hz" build) the frames are an even 16.7 ms: 1 % low 55.4–55.5 (the rest is ±1 ms timing jitter), long frames ~0, average 60.0 and thermal Nominal over 3 × 10 minutes, the same with `max_fps` 0 (V-Sync only). Sources: Godot ProjectSettings reference ("If true, iOS devices that support high refresh rate/"ProMotion" will be allowed to render at up to 120 frames per second"); Godot 4.7.2 source `drivers/apple_embedded/godot_view_apple_embedded.mm` (`CADisplayLink.preferredFramesPerSecond` from the view's preferred rate) and `platform/ios/display_server_ios.mm` (`screen_get_refresh_rate` from `UIScreen.maximumFramesPerSecond`); the export template's Info.plist always sets `CADisableMinimumFrameDurationOnPhone`. Proposal P1 below; not applied.
16. Startup target: debug builds needed ~8–15 s to the map on the tablet. **Release (2026-10-26, Phase 4a):** map ready 6.2 s (median of 30 launches, 6.0–9.2 s), first frame 6.7 s on the Galaxy Tab A7; 1.39 s / 1.46 s on the iPhone 13 Pro (debug 8.1 / 8.6 s and 1.54 / 1.61 s). Phase 4b: the tablet's launches during the measurement batches took 9.4 s to the map (median of 12; battery 34–39 °C), but alternating launches of the Phase 4a and 4b APKs at 30–31 °C gave 7.05 and 6.98 s, so the time depends on the tablet's state, not on the build; iPhone 1.37 s. What is acceptable is still open.
17. Is a visible loss of distant facade detail (beyond ~200 m) acceptable on the iPhone long term?
18. Automatic GPU/device detection for choosing a profile (instead of the per-platform rule), e.g. for strong Android phones or older iPhones?
19. A user-facing graphics settings menu to pick the profile?
20. *(Closed 2026-11-01 by D22 and T39: the generation scripts and their inputs are in the repository, and the current map is reproduced from them; `PROJECT_STATE.md`, "Map generator in the repository".)* Bringing the map generation scripts into the repository so map-level work is reproducible.
21. The map-level facade detail work (lighter facades, LODs, smaller cells): awaiting the user's decision and approval to change the map pipeline. Since 2026-11-01 the work can start from the scripts in the repository (T39). **Progress (2026-11-01):** smaller cells are done as the separate cells map (T40, D23): on the tablet's low profile no building within 50 m loses its facade detail any more (8.7 % within 100 m, from 34.6 %), with the device criteria met; lighter facades and LODs remain, and the order proposed from the measurements is in `PROJECT_STATE.md`, "Recommended next task". **Progress (2026-11-01, D24):** two lighter facades exist as experimental maps on the cells map: light (−50 % facade triangles, T41) and shader (−92 %, T42); which one, if any, is adopted is open question 42. **Progress (2026-11-01, D25):** the user chose the shader facade; its distant windows are filtered over the pixel footprint (T43); it did not become the default because of the tablet's long-frame criterion (open question 43). **2026-11-02 (D25):** with criterion 1 made relative it passed and became the default; facade LODs remain open.
22. Damage system: punches only signal hits (T21). Since Phase 5 an NPC plays a short hit reaction (user decision for Phase 5); health, damage values, death, and knockback are still undefined.
23. NPCs: *(answered for Phase 5, 2026-10-28, user: patrol between 2–3 points, a short hit reaction, no damage, attack, or pursuit; implemented on `PlayerController` with an AI input source, T35–T36.)* Still open: what NPCs should do beyond this (reacting to the player, crowds, traffic), and how many there should be (see question 34).
24. Roll damage immunity (invulnerability frames): none for now (D14). Revisit once damage exists.
25. *(Closed 2026-10-25 by D15: punch timings and stop-while-punching approved.)*
26. *(Closed 2026-10-25 by D15: the startup stays uncancellable.)*
27. *(Closed 2026-10-26 by D18: no change needed.)*
28. Speed-dependent camera distance while driving (optional in the task, not implemented).
29. Should steering also offer a drag or tilt mode (T25)?
30. Map colliders: all 827 are trimesh bodies (`ConcavePolygonShape3D`, 438,012 triangles; Phase 4a census). Should they be replaced by simple shapes (boxes or convex hulls per building, simplified ground) for cheaper physics? Phase 4a found the player and the parked car spending ~1 ms each per step against these trimesh bodies on the Galaxy Tab A7, with ~1.3 ms shared. This changes the map's collision, so it belongs to the same map-pipeline decision as the facade work (open questions 20–21): generate simple colliders in the map generation scripts rather than editing the imported GLB, and decide both together. The scripts are in the repository since 2026-11-01 (T39): colliders are the `-col` meshes that `build_map.py` names (`Ground_*`, `Buildings_*`, `TreeTrunks_*`, `Mosque_*`, `Landmark_*`, the bridges).
31. Further test devices: only the iPhone 13 Pro and the Galaxy Tab A7 exist; there is no Android phone (user, 2026-10-27). Phone screens other than the iPhone are checked only in the headless layout matrix with assumed insets (T29). Which devices should be added (a 20:9 Android phone with a punch-hole, a smaller or older iPhone, an iPad)? Since Phase 4d the device scenario (T33) can check any added device automatically.
32. Button sizes per device class: the smallest gameplay touch target is 18.3–21.6 mm on tablets (Tab A7, iPad) and 9.6–10.8 mm on phones (T29 matrix). Should tablets get smaller controls (closer to the thumbs, less of the picture covered) or small phones larger ones? Nothing changed for now.
33. The iPhone's two-orientation check (holding the joystick through a 180° turn) is still NOT RUN: in Phase 4d the gravity sensor showed the phone lying flat for the whole 90 s window; in Phase 5 the user answered that they could not do it ("Yapamam", not asked again). It needs the user to hold the phone upright and turn it once while `scenario_orientation` runs. The tablet passed the same check automatically (Phase 4d).
34. Character cost on the tablet: a walking character under `PlayerController` costs about 1.1–1.4 ms per physics step on the Galaxy Tab A7 (two physics steps per frame at its 30 FPS cap; three-run A/B in Phase 5); on the Mac it costs about the same on boxes as on trimesh, so most of it is script and transform work, not collision. NPCs far from the player are cheap (far mode, T35: 0.27–0.32 ms each), but two NPCs near the player at once cost 2.3–2.7 ms per step and about 2 FPS of the tablet's 1 % low. More NPCs near the player need a cheaper character (fewer script calls per tick, a C++/GDExtension controller, or near NPCs updated at a lower rate). Which NPC density is wanted, and on which devices?
35. Collisions between vehicles and characters: a moving vehicle passes through the player and the NPCs (vehicles do not mask the character layers, unchanged since Phase 3), and NPCs in the far mode pass through walls, cars, and each other. Should cars stop at, push, or hit characters (tied to question 22)?
36. The test district is packaged in every build (about 19 KB of scenes and data): debug and Release Perf builds can load it, normal release builds only load İstanbul. Keep it in release packages as a test map, or exclude `maps/test_district/` from release presets later? **Since 2026-11-01** the same applies to the cells map, and far more: a build made where its GLB is generated packs both imported maps (APK 428 MB instead of 224 MB, iOS `.pck` 402 MB instead of 198 MB); a release preset should exclude `assets/istanbul_halic_cells.glb` and `maps/istanbul_halic_cells/` unless it becomes the default (question 41). **Since the facade variants (2026-11-01)** a build made where all generated GLBs exist packs five maps (Release Perf APK 675 MB, iOS `.pck` 649 MB); a release package should contain one İstanbul map only, so a release preset must exclude every map the release does not load. **2026-11-01 (D25):** the default stayed İstanbul • Haliç, so a release package would still carry `assets/istanbul_halic.glb`; if the shader map becomes the default later, the release preset carries its GLB (255 MB, imported 102 MB) instead and excludes the others. **2026-11-02 (D25):** the shader map is the default, so a normal release package must carry `assets/istanbul_halic_cells_shader.glb` (generated on each machine; check its SHA-256 `60b9f729…` before exporting) and the cells map's occluders it uses (`maps/istanbul_halic_cells/istanbul_halic_cells_occluders.scn`), and should exclude the other maps' GLBs; exported without that GLB, a release falls back to the first map it does carry (`edadb59`), or shows the no-map error if it carries none. No release preset does this yet; a build made where all GLBs exist still packs five maps.
37. Map switching blocks the game while the new map loads: back to İstanbul took 6.8 s on the tablet and 1.8 s on the iPhone (device scenario), with a frozen frame. A user-facing map choice would need a loading screen or threaded loading (`ResourceLoader.load_threaded_request`). **Progress (2026-11-01):** a switch now shows a loading screen ("Yükleniyor...") without controls and frees the old map before loading the next; the load itself still blocks (6.8–9.5 s on the tablet in the debug build, with the screen standing still), and loading a big map holds 15–115 MiB of temporary data above its stable PSS (810 MiB peak on the tablet for the cells map). Threaded or partial loading is part of the streaming task (`PROJECT_STATE.md`, "Recommended next task").
38. ODbL share-alike (D22): the map is built from OpenStreetMap data (ODbL 1.0). Before any store release, decide how its terms apply to the published game (attribution in the app is required in any case; whether the map counts as a produced work or a derivative database decides whether share-alike applies), and where the attribution is shown.
39. *(Closed 2026-11-01 by D23: a separate id, `istanbul_halic_cells` first.)* A map regenerated from improved scripts (cells, facades, colliders, normals): does it replace the current İstanbul • Haliç (`assets/istanbul_halic.glb`) or join the registry under a separate id until it is measured? Replacing it changes every measurement baseline, the baked occluders (D13), and the tests that pin the current map (827 static bodies, 643 occluders, viewpoints, the vehicle spawn); a separate id (T34) allows A/B measurements on the devices first.
40. *(Closed 2026-11-01 by D23: regenerated on each machine, kept out of Git, the command and the expected SHA-256 recorded.)* Storing large generated outputs: the GLB is 502 MB and stays out of Git (D6). Generated outputs (GLB, per-cell scenes, occluders) could be regenerated on each machine from the pinned generator (about 2.5 minutes on the Mac), kept in external storage, or made small enough to commit. Which one?
41. *(Closed 2026-11-02 by D25: the shader facade map `istanbul_halic_cells_shader`, built on the cells map's data and cells, is the default; the cells map itself stays a selectable map. Decided for now 2026-11-01 by D24: not the default yet.)* When does the cells map (`istanbul_halic_cells`) become the default in place of İstanbul • Haliç? A user decision. Proposed criteria, all measured as in `PROJECT_STATE.md`, "Cell grouping and the cells map": (a) the user approves the side-by-side shots (`docs/perf/cells/shots/`); (b) Tab A7 low, three runs: average ≥ 29.9 and 1 % low not more than 0.5 FPS below İstanbul's same-session medians at all three viewpoints (measured: −0.19 / −0.05 / −0.02, met); (c) iPhone high: average ≥ 59.5 and long frames < 1 % (met), plus the 10-minute session with thermal ≤ Fair (not run); (d) memory and startup within limits the user sets (measured: tablet PSS 629 MiB against 501, map ready 7.8 s against 6.6 s; iPhone footprint 1,280 MiB against 1,000, map ready 1.6 s against 1.4 s); (e) the device scenarios pass on it; (f) a way to provide its GLB wherever builds are made (it is generated per machine, D23) and the tests that pin İstanbul's data moved to it. Replacing the default changes every measurement baseline.
42. *(Closed 2026-11-01 by D25: the shader facade; it becomes the default when D25's criteria pass. Criterion 1 failed on 2026-11-01, see question 43.)* Which facade variant is adopted, and when does a cells map become the default? A user decision that needs the visual approval of `docs/perf/facade/` (comparison sheets and the list of differences). Measured (`PROJECT_STATE.md`, "Lighter facades on the cells map"): **light** (−50 % facade triangles; mullions, sills, and windows behind neighbours gone) met every device criterion; **shader** (−92 %; flat windows, other glass tints, fainter far windows) met the averages, the 1 % low thresholds, the iPhone's 10-minute session, and brought the iPhone's footprint below İstanbul's, but had long-frame windows on the tablet at Galata. Neither lowers the tablet's PSS much (it follows the mesh count). Proposed criteria for a new default (from question 41, updated): (a) the user's visual approval; (b) the device criteria of this task in a fresh three-run session, long frames included; (c) the tablet's map switch fixed (the low-memory kills); (d) memory and startup within limits the user sets (tablet PSS, iPhone footprint, map ready); (e) a way to provide the generated GLB wherever builds are made (D23) and the tests that pin İstanbul's data moved; (f) a release preset that packs only that map (question 36).

43. Frame pacing of the low profile on the Galaxy Tab A7: some launches (about one in four in the 2026-11-01 batches: 4 of 18 in the A/B, 2 of 6 shader and İstanbul launches and 1 of 3 with a 31 FPS cap in the device measurements) run with frame times cycling about 28 → 42 → 30 ms for their whole duration, 0.7–12 % long frames per viewpoint at an average of 30.00 FPS and a 1 % low of 22.4–24.1, on any map; Phase 4a saw the same. A 31 FPS cap (Godot's CPU limiter out of Swappy's way) did not remove it; the window shader, the panels, a warm-up draw, and the render priority make no difference. It decides D25's criterion 1 by chance (one bad launch of three fails it). Candidates, each a change to the low profile or the project settings and so a user decision: Swappy's mode (`display/window/frame_pacing/android/swappy_mode`), frame pacing off, V-Sync modes, measuring the presented frames (Swappy statistics) to see whether the jitter is visible; or relaxing criterion 1 to the median over runs. Which, if any? *(2026-11-02: the user made criterion 1 relative to İstanbul • Haliç, D25, and kept the pacing settings; it passed.)* **Presented frames (2026-11-02, recorded only, no setting changed):** `tools/perf/present_trace.py` read the frames SurfaceFlinger presented from the game's surface during the 18 launches of D25's relative criterion (`dumpsys SurfaceFlinger --latency` every 2 s and TimeStats, aligned with the measurement windows through the monotonic engine log; `docs/perf/default_map/`). (1) The per-launch pacing state does not reach the screen: in İstanbul's bad launch the game loop counted 4.66 % long frames, while 1.36 % of the presented intervals were 50 ms, fewer than in the good launches; frame by frame, loop times of 18–46 ms were presented at an even 33 ms. (2) Every launch, good or bad, shows its own pairs of a 16.7 ms and a 50 ms interval on the screen: 2.6 % (shader map) and 3.5 % (İstanbul) of the presented intervals in the good launches, about one pair a second, while the loop counted 0.2 % long frames; the frames before a pair were queued and finished by the GPU on the usual cadence and only waited longer for the display, so they come from the hand-over to the display, not from the game's CPU or GPU time. So on this tablet the benchmark's long-frame count (the game loop) is not what the player sees: it over-reports a bad launch and does not see the display's pairs. The polling itself delays a composition now and then (counted out: intervals within 250 ms after a poll) and does not touch the game loop. Open: whether the visible pairs warrant work; a measurement task with presented-frame criteria (then Swappy's mode or frame pacing off, one change at a time) would tell whether a setting removes them.

## Constraints and priorities

- Safety and Git constraints: `AGENTS.md` sections 5–7.
- The map original in the source package must not be modified or deleted.
- Physical device results are reported as NOT RUN until actually performed.
- No store, TestFlight, or Play Console uploads; no release signing without explicit approval.
- Current priority: the map-level work chosen by the user (D22): the shader facade map is the default since 2026-11-02 (D25); next, the streaming loader ("Planned features") and, if the user wants it, a presented-frame measurement of the tablet's display pairs (open question 43). Safranbolu is deferred ("Deferred ideas").
