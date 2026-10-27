# Architecture

How the game code is organized and how to extend and test it. Implementation status lives in `PROJECT_STATE.md`; decision rationale lives in `PROJECT_CONTEXT.md`.

Engine: Godot 4.7.2, GDScript with static typing. 1 unit = 1 m; forward is -Z.

## Directory layout

```text
game/
  main.tscn, game.gd        Composition root (main scene)
  world/                    WorldManager, MapDefinition
  player/                   PlayerController, PlayerIntent, ActionBuffer, input sources, player.tscn
    state_machine/          PlayerStateMachine, PlayerState, Idle/Walk/Run/Punch/Roll states
    visual/                 CharacterVisual (interface), PlaceholderCharacterVisual (capsule tweens)
  combat/                   Hitbox, Hurtbox (hit detection only; no damage)
  vehicle/                  VehicleController, VehicleIntent, VehicleInputSource, TouchVehicleInput, VehicleDefinition,
                            VehicleInteraction (get in / out), placeholder_car.tscn
    definitions/            compact_car.tres (VehicleDefinition of the placeholder car)
    visual/                 VehicleVisual (interface), PlaceholderVehicleVisual (box body, cylinder wheels, lights)
  camera/                   ThirdPersonCamera, CameraProfile, on-foot and vehicle profiles
  input/                    MobileInputController, TouchControl, TouchLookArea, TouchButton
  ui/                       UIController, SafeAreaSource, hud.tscn, icons/ (button icons)
  quality/                  RenderSettings (applies render settings), QualityProfile, QualityProfiles, profiles/high.tres, low.tres
  debug/                    PerfConfig (experiments), PerfBenchmark, TrainingDummy (debug builds only)
maps/<map_name>/            One folder per map: scene, MapDefinition (.tres), map script, baked occluders (.scn)
assets/                     Map model and metadata (the 502 MB GLB is not in Git)
scripts/, main.tscn         Original explorer demo from the map package (desktop only, not used by the game)
tests/                      Headless test runner, unit and integration suites, fixtures (flat map, a second vehicle type)
tools/                      Development tools (screenshot capture, iOS debug build, occluder bake, perf scripts)
docs/                       This file, map documentation
build/                      Export output, ignored by Git except build/.gdignore (keeps Godot from importing it)
export_presets.cfg          "Android Debug", "Android Debug Compatibility", and "iOS Debug" presets
```

## Runtime structure

```text
Main (game.gd) ─ wires everything once in _ready()
├── WorldManager          loads maps/<map>/<map>.tscn from a MapDefinition; respawn and bounds
│   ├── IstanbulHalic     map scene: GLB, sky/ambient, sun, water shader, vertex-color fix
│   │   └── Occluders     baked occluders, added when the profile enables occlusion
│   ├── PlaceholderCar    VehicleController (VehicleBody3D, layer 4) per MapDefinition.vehicle_spawns
│   │   ├── Chassis, Cabin       collision boxes
│   │   ├── Wheel*        VehicleWheel3D ×4 (front steer, rear drive)
│   │   ├── Seat, ExitLeft, ExitRight  markers (driver's side is +X: the body drives along +Z)
│   │   ├── InteractionArea      Area3D (mask: player) — "vehicle in reach"
│   │   └── Visual        PlaceholderVehicleVisual (meshes only)
│   └── TrainingDummy     debug builds, on demand (DUMMY button): static target with a Hurtbox
├── Player                PlayerController (CharacterBody3D, layer 2)
│   ├── Visual            PlaceholderCharacterVisual → Pivot → Body, Visor, Fist (hidden at rest)
│   ├── Hitbox            Hitbox (Area3D, mask: hurtbox layer), open only in a punch's active phase
│   └── StateMachine      Idle, Walk, Run, Punch, Roll (child nodes)
├── ThirdPersonCamera     top-level rig → PitchPivot → SpringArm3D → Camera3D
├── TouchPlayerInput      PlayerInputSource: stick + camera yaw → PlayerIntent
├── TouchVehicleInput     VehicleInputSource: vehicle buttons/keys → VehicleIntent (given to the driven vehicle)
├── VehicleInteraction    get in / get out: seats the player, swaps HUD group, input source, camera profile
└── HUD                   UIController (CanvasLayer): safe area (SafeAreaSource), debug overlay
    └── SafeArea/Controls MobileInputController
        ├── LookArea      TouchLookArea (right 58 %), both modes
        ├── OnFootControls      group shown on foot
        │   ├── Joystick        native VirtualJoystick (left 42 %), drives move_* actions
        │   ├── RunButton       TouchButton, toggle
        │   ├── PunchButton     TouchButton, one-shot press on touch-down
        │   ├── RollButton      TouchButton, one-shot press on touch-down; faded during the roll cooldown
        │   └── InteractButton  TouchButton (car icon), visible only with a vehicle in reach
        ├── VehicleControls     group shown while driving
        │   ├── SteerLeftButton, SteerRightButton   hold (left side)
        │   ├── ThrottleButton, BrakeButton, HandbrakeButton "P"   hold (right side)
        │   └── ExitButton      one-shot (top right); faded while too fast to get out
        ├── DebugViewButton     TouchButton "VIEW", debug builds only (extra_controls)
        ├── DebugQualityButton  TouchButton "Q", cycles quality profiles, debug builds only
        ├── DebugDummyButton    TouchButton "DUMMY", toggles the training dummy, debug builds only
        └── DebugCarButton      TouchButton "CAR", walks the player up to the vehicle, debug builds only
```

`game.gd` also owns a `RenderSettings` object (created after the map loads) that applies the quality profile.

Systems do not search for each other. `game.gd` is the only place that connects them.

## Per-frame data flow

1. **Touch.** The native `VirtualJoystick` writes the `move_left/right/forward/back` actions. `MobileInputController._input()` routes every other touch to one `TouchControl` in priority order (run, punch, roll, interact buttons, the vehicle buttons, `extra_controls`, then look area; hidden controls are skipped) and owns that finger until release. A finger that starts on the look area keeps turning the camera even if it slides over a button. Unclaimed touches fall through to the GUI, where the joystick takes them. A punch or roll button touch-down (or the J / Space key) records a one-shot press that is kept until consumed once (`consume_action_press()`).
2. **Camera (`_process`).** `ThirdPersonCamera` consumes the look delta (radians), clamps pitch, follows the target's interpolated transform, and lets the `SpringArm3D` (sphere, world layer) pull the camera in front of walls.
3. **Player (`_physics_process`).** `PlayerController` clears its `PlayerIntent` and asks its `input_source` to fill it. `TouchPlayerInput` rotates the stick by the camera yaw (`camera_relative`) and copies the pending punch/roll presses into the intent's one-shot fields. The controller puts those presses into its `ActionBuffer`. The active `PlayerState` starts a buffered action or picks the target speed and transitions; `apply_locomotion()` accelerates, turns the body, and applies gravity. Then the buffer ages, `move_and_slide()` runs, and `CharacterVisual.set_locomotion()` gets the horizontal speed.
4. **Vehicle (`_physics_process`).** The driven `VehicleController` asks its `input_source` (`TouchVehicleInput`) for a `VehicleIntent`, turns it into steering, engine force, and per-wheel brakes (`drive_command()`, `steer_angle()`, `approach_steer()`), checks its reset conditions, and passes speed, steering, lights, and wheel poses to its `VehicleVisual`. An intent `exit` press asks `VehicleInteraction` to let the player out. Parked vehicles have no input source and hold the handbrake; once at rest they fall asleep and skip all of this until woken (see "Parked vehicles sleep").
5. **World (`_physics_process`).** `WorldManager` respawns tracked bodies below `kill_height` and clamps them to `bounds` (the player is untracked while driving; vehicles reset themselves).

## Module map

The specification suggested these modules. Status as of Phase 4b:

| Module | Implementation | Status |
|---|---|---|
| PlayerController | `game/player/player_controller.gd` | Phase 1 |
| PlayerStateMachine | `game/player/state_machine/` | Phase 1: Idle, Walk, Run; Phase 2: Punch, Roll |
| ThirdPersonCamera | `game/camera/third_person_camera.gd` + `CameraProfile` | Phase 1 |
| MobileInputController | `game/input/mobile_input_controller.gd` + touch controls | Phase 1 |
| WorldManager | `game/world/world_manager.gd` + `MapDefinition` | Phase 1 |
| UIController | `game/ui/ui_controller.gd` | Phase 1: safe area, debug overlay |
| Quality profiles | `game/quality/` (`RenderSettings`, `QualityProfile`) | High (iOS) and Low (Android) |
| PlayerCombat | `PunchState`, `RollState`, `ActionBuffer`, `game/combat/` (`Hitbox`, `Hurtbox`) | Phase 2: punch, roll; no damage system |
| PlayerAnimation | `game/player/visual/` (`CharacterVisual` interface, `PlaceholderCharacterVisual`) | Phase 2: placeholder tweens; no model or animations yet |
| VehicleController | `game/vehicle/vehicle_controller.gd` + `VehicleDefinition`, `VehicleIntent`, `VehicleInputSource`, `VehicleVisual` | Phase 3: placeholder car on GodotPhysics3D `VehicleBody3D`; Phase 4b: parked vehicles sleep |
| VehicleInteraction | `game/vehicle/vehicle_interaction.gd` | Phase 3: get in / out, HUD and camera handover |

## Extension points

- **New map:** add `maps/<name>/<name>.tscn` and a `MapDefinition` resource (scene path, spawn position and yaw, bounds, kill height), then point `Main.map_definition` at it. Player, camera, and input code stay unchanged.
- **New player action:** add a `PlayerState` child under `Player/StateMachine` and a one-shot field on `PlayerIntent`; buffer its press in `PlayerController._physics_process()` and start it from `PlayerState.start_buffered_action()`. States switch with `machine.transition_to(&"Name")`. Punch and roll are the worked examples (see "Character actions").
- **Character model and animations:** replace the `Visual` node of `player.tscn` with a `CharacterVisual` subclass (see "CharacterVisual extension point"). `PlayerController` and the states stay unchanged.
- **Hit targets (NPCs, props):** give the target a `Hurtbox` (physics layer 3) and react to `hit_received(attacker)`. Damage and reactions belong to the target.
- **Other drivers (AI, bots, replays):** subclass `PlayerInputSource` and implement `fill_intent()`. The controller does not know where intents come from.
- **New vehicle type:** see "Vehicles (Phase 3)", "Adding a vehicle type". A scene plus a `VehicleDefinition`; no code.
- **Other vehicle drivers (AI, replays):** subclass `VehicleInputSource` and set it as the vehicle's `input_source`.
- **New touch control:** subclass `TouchControl`, add it under `HUD/SafeArea/Controls`, and register it in `MobileInputController`'s priority list.

## Physics layers

| Layer | Name | Used by |
|---|---|---|
| 1 | world | Map static bodies (GLB `-col` nodes). Mask of the player and the camera spring arm. |
| 2 | player | Player body. |
| 3 | hurtbox | `Hurtbox` areas (training dummy). Mask of the punch `Hitbox`, which is on no layer. |
| 4 | vehicle | Vehicle bodies. Mask: world and vehicle. The player and the camera spring arm mask layers 1 and 4 (value 9), so the player cannot walk through a car and the camera stays out of it. A vehicle's `InteractionArea` masks layer 2 (player). |

The map has collision on `Ground_*` terrain (streets included), `Buildings_*`, `Mosque_*`, `TreeTrunks_*`, landmarks, and the two bridge decks. Roads, pavements, railings, lamps, decor, and water have no collision of their own. The debug training dummy's body is on layer 1, so the player and the camera spring arm collide with it.

## Input

- Touch is primary. Several fingers work at once; each finger belongs to one control until it lifts.
- Running is a toggle button that turns off when the joystick finger lifts (`run_resets_on_release`).
- Punch and roll buttons fire on touch-down; holding does not repeat, and a drag that starts on them never turns the camera.
- Vehicle controls (shown only while driving): two hold buttons on the left steer (smoothed to an analog value by `steer_rate`), throttle, brake (reverses near standstill), and handbrake "P" on the right, exit at the top right. Getting in uses the on-foot interact button. `set_vehicle_mode()` switches the groups and releases every finger and pending press; punch and roll presses are ignored while driving.
- Desktop development: WASD or arrow keys move (and drive), Shift runs, J punches, Space rolls (handbrake while driving), E gets in and out, and the mouse emulates touch (`emulate_touch_from_mouse`), so left-drag on the left half is the joystick and left-drag on the right half turns the camera.
- When the app loses focus or pauses, `MobileInputController.release_all_touches()` drops routed fingers and pending punch/roll presses, turns the run toggle off, sends touch releases so the native joystick forgets its finger, and releases all input actions (`ACTIONS`, vehicle ones included). `PlayerController` receives the same notifications and ends a running punch or roll (`interrupt_actions()`); a `VehicleController` drops the throttle and holds the handbrake until a pedal is pressed again (`release_controls()`).

## Character actions (Phase 2)

Punch and roll are `PlayerState`s (`PunchState`, `RollState`), not conditions inside the locomotion states.

| Tunable (exported) | Default | Where |
|---|---|---|
| Input buffer window | 0.18 s | `PlayerController.input_buffer_time` |
| Punch startup / active / recovery | 0.10 / 0.10 / 0.25 s | `PunchState` |
| Speed while punching | 0 m/s (stops) | `PunchState.move_speed` |
| Roll duration / distance / cooldown | 0.6 s / 6 m / 0.8 s | `RollState` |
| Horizontal speed kept after a roll | 4.5 m/s | `RollState.exit_speed` |

- **Buffer.** A press is kept for the window (`ActionBuffer`) and dropped afterwards. Locomotion states start a buffered action at the top of their tick: roll first, then punch. Actions start only on the floor (`is_on_floor()`); presses in the air wait in the buffer and expire.
- **Punch.** Startup, then the active phase with the `Hitbox` open (and only then), then recovery; the body decelerates to `move_speed` and keeps its facing. Afterwards a buffered action or the locomotion state matching the stick follows.
- **Roll.** Direction = the intent's movement (camera-relative stick) if any, else the body's facing (`RollState.roll_direction()`); the body turns to it at once. Constant speed `distance / duration`; gravity and `move_and_slide()` keep working, so a roll can leave a bridge deck (the respawn below `kill_height` applies). Roll presses during the roll and its cooldown are ignored (blocked in the buffer), not delayed.
- **Interplay.** A punch pressed during a roll runs when the roll ends if the press is younger than the window. A roll cancels only the punch recovery; a roll pressed during startup or active waits in the buffer and starts on the first recovery tick if it is still young enough. A punch pressed during a punch chains after it the same way.
- **Interruption.** Focus loss or pause: `PlayerController.interrupt_actions()` clears pending presses and switches to Idle; `exit()` closes the hitbox and resets the visual. `teleport()` (spawn, respawn, VIEW) does the same.
- **Hits.** `Hitbox` (Area3D, mask layer 3) hits each `Hurtbox` at most once per activation and calls `Hurtbox.receive_hit(attacker)`, which emits `hit_received`. No damage, knockback, or immunity.
- **Camera.** Unchanged: it follows the player's interpolated transform in `_process`, so the roll's 10 m/s is interpolated like walking (`test_roll_follows_camera_and_camera_follows_roll`).

### CharacterVisual extension point

States ask for visual feedback only through `CharacterVisual` (`game/player/visual/character_visual.gd`), referenced by `PlayerController.visual`:

| Method | Called by | When |
|---|---|---|
| `set_locomotion(speed, on_floor)` | `PlayerController` | every physics tick, after `move_and_slide()` |
| `play_action(action, duration, impact)` | `PunchState.enter()` (`&"punch"`, 0.45 s, impact 0.1 s = start of active), `RollState.enter()` (`&"roll"`, 0.6 s, no impact) | action starts |
| `stop_action()` | `PunchState.exit()`, `RollState.exit()` | action ends, is cancelled, interrupted, or the player teleports |

`PlaceholderCharacterVisual` implements it with tweens on the capsule (lean with speed; the fist thrusts forward on the punch; tuck and one forward turn on the roll). Its tweens run on physics ticks (`Tween.TWEEN_PROCESS_PHYSICS`), so physics interpolation smooths them like the body.

An animated model plugs in as another subclass, for example `AnimatedCharacterVisual` with the model and an `AnimationTree`: `set_locomotion()` sets a locomotion `BlendSpace1D` position from the speed (and a falling state from `on_floor`); `play_action()` fires a `OneShot` or travels an `AnimationNodeStateMachine` to the action, scaling the clip so it lasts `duration` and its contact frame lands at `impact`; `stop_action()` aborts the one-shot and returns to locomotion. Replace the `Visual` node in `player.tscn` with that scene and point `PlayerController.visual` at it; no controller or state code changes. Hit timing stays with `PunchState`, so gameplay does not depend on animation lengths. `test_visual_can_be_replaced` swaps in a recording visual to check this contract.

## Vehicles (Phase 3)

A vehicle is a `VehicleBody3D` scene with `VehicleController` (`game/vehicle/`), following the same intent pattern as the player: a `VehicleInputSource` fills a `VehicleIntent` (`steer` −1..1, `throttle` 0..1, `brake` 0..1, `handbrake`, one-shot `exit`) every physics tick, and the controller never reads raw input. Tunables live in a `VehicleDefinition` resource; meshes live behind `VehicleVisual`.

Physics engine: the project runs **GodotPhysics3D** (the `"DEFAULT"` setting in Godot 4.7.2; `STARTUP … physics_3d=GodotPhysics3D (setting DEFAULT)`). Measured `VehicleBody3D` behaviour on it, which the controller relies on:

- The body drives along **+Z**, so vehicles face +Z (the player faces −Z). `get_follow_yaw()` (`rotation.y + PI`) tells the camera where "behind" is; `place_at(t)` turns the body so that its +Z points along a map transform's −Z (map spawns and viewpoints keep the player's convention).
- Positive `steering` turns **left** with front-wheel steering, so the controller negates the intent's steering (intent +1 = right).
- The project's default linear damping (0.1) capped the top speed near 15 m/s; vehicles replace it with `VehicleDefinition.linear_damp` (0).
- 8° of steering at 21 m/s rolled the car over; the steering angle narrows with speed to `steer_at_max_speed_degrees` (5°), checked by `test_throttle_accelerates_forward_up_to_max_speed`.

| `VehicleDefinition` (compact car) | Value | Meaning |
|---|---|---|
| `mass`, `center_of_mass`, `linear_damp` | 1200 kg, (0, 0.25, 0), 0 | low centre of mass against rollover |
| `engine_force`, `max_speed` | 3000 N per traction wheel, 22 m/s | force fades linearly to 0 at max speed |
| `reverse_force`, `max_reverse_speed`, `reverse_threshold` | 2000 N, 6 m/s, 1 m/s | brake held below the threshold reverses |
| `brake_force`, `handbrake_force`, `coast_brake`, `hold_speed` | 30, 60 (rear wheels), 1, 0.5 m/s | no pedal: coast; no pedal below `hold_speed`: brakes hold (hills) |
| `max_steer_degrees`, `steer_at_max_speed_degrees`, `steer_rate`, `steer_return_rate` | 30°, 5°, 3/s, 4/s | button steering ramps to an analog value |
| `safe_exit_speed` | 1.5 m/s | getting out allowed at or below |
| `flip_angle_degrees`, `flip_reset_seconds`, `flip_reset_max_speed` | 70°, 2 s, 2 m/s | flipped and nearly still for 2 s → reset |
| `sleep_when_parked`, `sleep_after_seconds`, `sleep_linear_speed`, `sleep_angular_speed` | on, 1 s, 0.1 m/s, 0.1 rad/s | parked at rest for 1 s → asleep (Phase 4b) |
| `camera_profile` | `vehicle_camera_profile.tres` | 7.5 m distance, 1.9 m pivot, follow mode |

- **Drive rules** (`VehicleController.drive_command()`): throttle accelerates (and first brakes a vehicle rolling backwards); brake slows a vehicle moving forward faster than `reverse_threshold` and reverses below it; both pedals brake; the handbrake cuts the engine and brakes the rear wheels. Without an input source (parked) or after focus loss / pause (`release_controls()`), the handbrake holds until a pedal is pressed.
- **Getting in** (`VehicleInteraction`): the vehicle's `InteractionArea` tracks the player; the interact button shows while a vehicle is in reach and the player stands on a floor. Entering calls `PlayerController.set_seated(true)` (hidden, collision shape disabled, no physics processing, actions and presses dropped), keeps the player at the `Seat` marker every tick, switches `MobileInputController` to vehicle mode, gives the vehicle `TouchVehicleInput`, and calls `ThirdPersonCamera.set_target(vehicle, definition.camera_profile)`. `game.gd` untracks the player in `WorldManager` meanwhile.
- **Getting out** (`request_exit()`): refused at speeds above `safe_exit_speed` ("speed"; the exit button is faded meanwhile). Otherwise `find_exit_transform()` tries each exit marker in order (driver's side first): a ray finds the floor under it, and a shape query with the player's capsule must find no world or vehicle collider there; if no marker qualifies the exit is refused ("blocked"). Refused presses are dropped. On success the vehicle is parked (handbrake), the player is placed and unseated, and the on-foot controls and camera profile return.
- **Reset:** below the map's `kill_height`, or flipped as above, the vehicle returns to its spawn (`spawn_transform`), and a seated driver goes with it.
- **Parked vehicles sleep** (Phase 4b, P2): see below.
- **Camera follow mode:** `CameraProfile.follow_yaw_sharpness` > 0 swings the yaw back behind the target after `follow_delay` seconds without look input (vehicle profile: 2.5, 1 s); the on-foot profile keeps 0 (no change from Phase 1). The spring arm masks the world and vehicle layers and excludes the followed body.
- **Placement:** `MapDefinition.vehicle_spawns` (transforms facing −Z); `WorldManager.spawn_vehicles(Main.vehicle_scene)` parks one vehicle per entry; `game.gd` registers them with `VehicleInteraction`. VIEW moves the vehicle instead of the player while driving.
- **HUD cost** (Mac, low profile, same view): HUD hidden 67 draw calls; on-foot HUD 105 (+5 while the interact button shows); vehicle HUD 118.

### Parked vehicles sleep (Phase 4b)

A `VehicleBody3D` at rest is never put to sleep by GodotPhysics3D: the engine's own sleep test marks it inactive at the end of a step, and its wheel raycasts apply suspension impulses in the next state callback, which wake it again. So it is simulated every step, and between steps (where the overlay and the benchmark look) it reads as inactive and `RigidBody3D.sleeping` as `true`. Phase 4a measured ≈ 1 ms per physics step on the Galaxy Tab A7 for the unused parked car. `VehicleController` therefore puts it to sleep itself:

| Rule | Where | Value (compact car) |
|---|---|---|
| Sleeps when: no driver (`input_source` null), all wheels in contact, linear speed < `sleep_linear_speed`, angular speed < `sleep_angular_speed`, for `sleep_after_seconds` | `_update_rest()`; `VehicleDefinition`, group "Parking" (`sleep_when_parked` switches it off) | 0.1 m/s, 0.1 rad/s, 1.0 s |
| Sleeping = `RigidBody3D.sleeping = true`: the physics server stops simulating the body (no wheel raycasts, suspension, or solver work); velocities are zeroed; brake values stay set | | |
| State: `is_asleep()` is true while the parking rule put the vehicle to sleep and the physics server still has it inactive (`BODY_STATE_SLEEPING`); neither the `sleeping` property nor the server state alone is reliable (above). `sleep_changed(asleep)` fires at once for the rule and `wake_up()`, and on the next tick for a wake by the engine | | |
| Wakes when a driver gets in (the `input_source` setter) | `wake_up()` | |
| Wakes when moved or reset: `place_at()` (spawn, VIEW, teleports), `reset_to_spawn()` | `wake_up()` (setting the velocities there already wakes the body in GodotPhysics3D; the call keeps the rule independent of that) | |
| Wakes when a rigid body hits it | the physics engine (sleeping rigid bodies join the island of the body that touches them) | |
| Wakes when the player walks into it (kinematic bodies do not wake it by themselves) | `PlayerController._wake_bodies_touched()`, only while `is_on_wall()` and the intent moves (Phase 4c: standing still against a car on a slope keeps a wall contact and kept it awake); calls `wake_up()` on colliders that have it | |
| Wakes when the ground under a wheel is gone (floor removed or switched off) | `_check_ground()`: while asleep, one ray per wheel along the body's down axis every `GROUND_CHECK_INTERVAL` (0.25 s), length radius + rest length + 0.15 m | |

- While asleep, `_physics_process()` only checks the ground; engine, brake, and steering values and the visual stay as they were, so the parked handbrake and hold brakes are still set when it wakes. On a slope it does not move while asleep, and after waking the usual rules apply (parked: handbrake; driver without pedals: hill hold). The `InteractionArea` is a separate `Area3D` and keeps detecting the player while the vehicle sleeps.
- The player cannot push a vehicle (vehicles do not mask the player layer, unchanged from Phase 3), so a player bump only wakes it; it falls asleep again 1 s after the contact ends.
- **Why sleep, not freeze:** measured headless on the real map (`tools/perf/vehicle_sleep_cost.gd`, `docs/perf/phase4b/headless/vehicle_sleep_cost.txt`): both take the body out of the server's active list (0 active bodies) and cost the same as removing the vehicle from the simulation within noise. A sleeping body stays a rigid body that the engine wakes on contact (a thrown 400 kg box woke it and pushed it 0.38 m), while a frozen (static) body stays an immovable wall that does not wake (the same box moved it 0.000 m) and every wake case would need manual handling.
- **Not `can_sleep = false`:** switching the engine's own sleep test off would make the server state reliable between steps, but then any active body sharing the vehicle's island (the player standing against it, a box resting on it) wakes it after every step, so it never stays asleep (tried in Phase 4b; `test_walking_into_a_sleeping_vehicle_wakes_it` and `test_a_body_hitting_a_sleeping_vehicle_wakes_it` failed).
- Debug overlay: `car asleep|awake` after the player's (or, while driving, the vehicle's) speed; `PERF … vehicles=asleep`; `VEHICLE <name> asleep|awake` log line on each change (debug and Release Perf builds); `STARTUP … vehicles=…` and `startup.vehicles`; benchmark results record `vehicles_asleep` (share of frames).

### Adding a vehicle type

1. Create a scene with a `VehicleBody3D` root using `vehicle_controller.gd`: collision shapes, four (or more) `VehicleWheel3D` children (`use_as_steering` / `use_as_traction`, suspension and friction), a `Seat` marker, exit markers in the order to try (driver's side first), an `InteractionArea` (Area3D, mask layer 2) around it, and a `VehicleVisual` subclass with its meshes. Forward is +Z; the driver's side is +X. Set `collision_layer` 8 (vehicle) and `collision_mask` 9.
2. Create a `VehicleDefinition` resource with its mass, engine, brakes, steering, exit speed, reset rule, and camera profile, and assign it to the root's `definition`.
3. Put the scene in `Main.vehicle_scene` (or spawn it yourself and call `VehicleInteraction.register_vehicle()`).

`tests/fixtures/test_van.tscn` + `test_van_definition.tres` are a second type made this way (heavier, 14 m/s top speed, other wheelbase and exit points); `test_second_vehicle_type_from_definition_and_scene` and `test_second_vehicle_type_enter_and_exit` drive it and get in and out without any code change.

## Debug measurement tools (debug builds only; STARTUP also in Release Perf builds)

- Overlay (top left): FPS, draw calls, primitives, objects, video memory, engine static memory (current and peak), player state and speed on foot or the driven vehicle's forward speed (`Driving 12.3 m/s`), each vehicle's physics state (`car asleep`), current viewpoint, quality profile.
- Log lines: `PERF profile=… view="…" fps=… draw_calls=… … vehicles=asleep` every 2 s; `QUALITY profile=… experiment=… occluders={…} effective={…}` whenever settings are applied; `STARTUP map_ready_ms=… first_frame_ms=… profile=… occluders={…} physics_3d=<engine> (setting <value>) vehicles=… build={…}` once; `VEHICLE <name> asleep|awake` on each sleep change; `VIEW <name>` on each switch.
- Q button: cycles quality profiles none → high → low (the debug experiment, if any, stays on top).
- VIEW button: cycles Spawn → the map's `debug_viewpoints` (`MapDefinition`, names in `debug_viewpoint_names`). While driving it moves the vehicle there.
- CAR button: puts the player beside the driver's door of the map's first vehicle (it is parked far from the player spawn); logs `CAR walk-up`.
- DUMMY button: places a training dummy 1.3 m in front of the spawn (0.35 m to the right, so the camera sees it) or removes it. It shows `HITS <n>` above itself and logs `DUMMY hits=<n>` per hit; off by default, so benchmarks and tests run without it.
- Reading the logs: Android `adb logcat -s godot`; iOS: Godot output goes to the unified log, not to `devicectl --console`; record it with `xcrun xctrace record --template Logging --device <udid> --all-processes` and export the `os-log` table. Screenshots: `adb exec-out screencap -p`, `xcrun devicectl device capture screenshot`. iOS memory and thermal state: Instruments "Activity Monitor" template (`memory-physical-footprint`, `device-thermal-state-intervals`).

## Rendering and performance settings

- Mobile renderer on all platforms (`rendering_method` and `rendering_method.mobile`). Measured on macOS: Metal, "Forward Mobile".
- Quality profiles change the values below on devices; see "Quality profiles".
- Sun: 2-split directional shadows, 60 m distance (the original demo used 4 splits and 450 m).
- Camera far plane 1500 m. MSAA 3D 2× (inherited from the map project). Physics interpolation is on (60 Hz physics, smooth at any display rate).
- **iOS display refresh rate (Phase 4b, P1):** `display/window/ios/allow_high_refresh_rate = false` in `project.godot`, so ProMotion iPhones run the engine's display link at 60 Hz instead of 120 Hz (Godot 4.7.2 `platform/ios/godot_view_ios.mm`: `preferredFrameRate` 60 or 120 from this setting). With 120 Hz and the high profile's 60 FPS cap, frames alternated 8.3 / 25 ms (Phase 4a). The setting is read only by the iOS platform code; Android and desktop are unaffected (Android keeps Swappy frame pacing and the low profile's 30 FPS cap). `screen_get_refresh_rate()` still reports the panel's maximum (120; `UIScreen.maximumFramesPerSecond`), so `build_info()` adds `display_refresh_rate` (60 on iOS with the setting off), which `tools/perf/median.py --pacing` uses.
- Landscape (`sensor_landscape`), 1440×900 base canvas with `canvas_items` stretch and `expand` aspect, so phones get a wider canvas at 900 units tall.
- Touch sizes: joystick 220 units, run and roll buttons 124 units, punch button 140 units (hit areas 1.15× the drawn radius). On an iPhone 13 Pro (1170 px landscape height, 460 ppi) that is about 95 pt / 16 mm, 54 pt / 9 mm, and 61 pt / 10 mm; Apple's minimum touch target is 44 pt. Calculated from the layout; the layout matrix checks every screen (see "Safe area and screen layouts"). Buttons sit bottom-right inside the safe area: run in the corner, punch to its left, roll above it; their hit areas do not overlap (`test_action_buttons_layout`).

## Safe area and screen layouts (Phase 4c)

- **Source:** `UIController.safe_area_source` (`SafeAreaSource`, `game/ui/safe_area_source.gd`) gives the window size and the display safe area in window pixels. The default asks `DisplayServer` (`get_display_safe_area()` on mobile; on desktop there is none and the whole window is safe), so devices behave as before. `SafeAreaSource.fixed(window, safe)` stands in for any screen in tests and in the screenshot tool.
- **Applying:** `apply_safe_area()` converts the safe area to canvas units (`safe_rect_in_viewport()`; `UIController.safe_rect` keeps the result) and insets `SafeArea` by it plus `edge_margin` (16 units). It runs at start, on viewport size changes, and when the HUD's check every `SAFE_AREA_CHECK_INTERVAL` (0.25 s) sees a different window size or safe area: a 180° turn between the two landscape orientations moves a punch-hole or a navigation bar to the other side without a size change, which the viewport never reports. Any change after the first layout calls `MobileInputController.release_all_touches()`, as on focus loss, so a held joystick or button cannot stay down on a control that moved. Debug and Release Perf builds log `SAFE_AREA window=… safe=… canvas=… viewport=…` on every application. Notched iPhones report symmetric side insets in landscape (47 pt each on the iPhone 13 Pro, per Apple's layout guides; the device's own line was not captured in Phase 4c), so a turn changes nothing there.
- **Layout matrix** (`tests/unit/test_hud_layout.gd`): nine screens with their safe areas in window pixels (`SCREENS`): 16:9 1920×1080; 19.5:9 iPhone 13 Pro 2532×1170 with the notch on the left and on the right; 20:9 2400×1080 with a punch-hole (110 px) on either side and a 3-button bar (126 px) on the other side or a gesture handle (63 px) at the bottom; 4:3 iPad 2048×1536; 16:10 Tab A7 2000×1200. For each, on foot (with the interact button) and in the vehicle, with the debug overlay and buttons shown, it checks: every visible button inside the platform safe area; hit circles (drawn radius × `hit_scale`) apart; the right-side buttons entirely over the camera drag area and the steering buttons entirely left of it; the joystick zone left of the camera drag area and the joystick at rest (its `initial_offset_ratio`, radius `joystick_size / 2`) inside the safe area and clear of every button; the debug label clear of every button; every hit target and the joystick at least 7 mm on the device (`MIN_TARGET_MM`; Apple's 44 pt minimum is ~7 mm on an iPhone). Size on the device = hit diameter in canvas units × window pixels per canvas unit (the root's final transform: `min(window.x / 1440, window.y / 900)` with `expand`) ÷ the screen's pixels per inch × 25.4. Insets of the Android phones and the ppi values are assumed typical values, not measured devices. The test prints one `layout …` line per screen and group (canvas size, scale, smallest target and gap); results: `PROJECT_STATE.md`, "Phase 4c".
- **Adding a screen:** add an entry to `SCREENS` (window size, safe area in window pixels as the platform reports it, ppi) and a `test_<name>()` that calls `_check_screen()`; take a reference shot with `tools/capture_screenshot.gd --safe-area=…` (below) at a smaller resolution with the same aspect ratio, scaling the safe area by the same factor. Reference shots: `docs/ui/`.

## Testing

```bash
godot --headless --path . --import                                 # after adding or renaming scripts
godot --headless --path . --script res://tests/run_tests.gd         # all suites
godot --headless --path . --script res://tests/run_tests.gd -- unit # unit suite only
godot --headless --path . --script res://tests/map/validate_scene.gd # original map validation
```

- Output: one `PASS`, `FAIL`, or `SKIP` line per test, then `RESULT <n> passed, <n> failed, <n> skipped`.
- A test fails when a check fails **or** when any engine or script error is logged while it runs (captured with a `Logger` via `OS.add_logger`). GDScript runtime errors abort only the failing function, so a test that crashes halfway would otherwise look like a pass. Warnings are printed but do not fail a test. A test file that fails to load counts as a failure.
- Exit code: `0` no failures and no skips; `1` any failure, an error logged outside a test, or nothing passed; `2` no failures but some tests skipped.
- Other engine settings for a one-off run (measurement only): put a temporary `override.cfg` in the project root and delete it afterwards, e.g. `[physics]` `3d/physics_engine="Jolt Physics"` or `common/physics_ticks_per_second=30`. Results of 2026-10-26: `docs/perf/phase4a/headless/`. Many timing tests count 60 Hz ticks, so a 30 Hz run fails them without a gameplay change; see `PROJECT_STATE.md`.
- Collider census (types, triangles, bodies near each viewpoint): `godot --headless --path . --script res://tools/perf/collider_census.gd`.
- `tests/unit/` runs without the map. `tests/integration/` loads the real map; when `assets/istanbul_halic.glb` is missing its tests are reported as `SKIP` (via the file's `skip_reason()`), and the full run exits 2.
- Tests send touches through `Input.parse_input_event`, the same pipeline device touches use, with positions converted from canvas units to window pixels.
- Visual check without a device (opens a window):

  ```bash
  godot --path . --resolution 1266x585 --script res://tools/capture_screenshot.gd -- --out=/abs/path/shot.png --walk --run
  ```

  The tool prints renderer, FPS, draw calls, and primitive counts for the frame. `--punch` / `--roll` tap that button, `--frames=N` takes the shot N frames later (mid-action poses), `--dummy` shows the training dummy, `--vehicle-hud` shows the vehicle control group, `--safe-area=X,Y,W,H` gives the HUD a safe area in window pixels and shades the area outside it, `--release-hud` hides the debug overlay and buttons. Example (iPhone 13 Pro at half size): `--resolution 1266x585 … -- --safe-area=70,0,1125,553 --release-hud`.

## Quality profiles

Permanent render settings per device class, applied in every build.

| Profile | Default on | Settings (unset keys keep the scene default) |
|---|---|---|
| none | desktop, editor, tests | none |
| high | iOS | 60 FPS cap, occlusion culling, 200 m visibility range for trees, lamps, decor, facade detail |
| low | Android | 30 FPS cap, occlusion culling, 100 m visibility ranges (same categories), 400 m far plane with depth fog, shadows off, 0.6 render scale, LOD threshold 4 |

- **Resources:** `QualityProfile` (`game/quality/quality_profile.gd`), `game/quality/profiles/{high,low}.tres`. `to_settings()` returns only the keys the profile sets.
- **Selection** (`QualityProfiles`, strongest first): a debug experiment's `profile` key → `--quality=<none|high|low>` on the command line → platform rule (`OS.has_feature("ios")` → high, `"android"` → low, otherwise none). No GPU detection.
- **Applying:** `RenderSettings` (`game/quality/render_settings.gd`) applies a settings dictionary over the defaults it captured from the scene: map-category visibility and visibility ranges, camera far plane, depth fog on the loaded environment, sun shadow mode, viewport scale/LOD/occlusion, `Engine.max_fps`. Keys a layer leaves out are reset to the defaults, so `set_quality_profile()` can switch at runtime.
- **Precedence:** experiment > profile > defaults (`RenderSettings.merge`, per key; dictionary keys such as `visibility_end` are replaced as a whole).
- **Occluders:** with occlusion on, `RenderSettings` loads `MapDefinition.occluders_path` (baked); if it is missing it builds occluders from the `buildings` and `ground` collision and logs a warning.
- **Baking occluders** (after any map change):

  ```bash
  godot --headless --path . --import
  godot --headless --path . --script res://tools/bake_occluders.gd   # -- --map=res://maps/<name>/<name>.tres
  ```

  Output for İstanbul • Haliç: `maps/istanbul_halic/istanbul_halic_occluders.scn`, compressed binary, 2,300,873 bytes; 643 occluders, 317,518 triangles, 206,048 shared vertices (the runtime build has 952,554 unshared). `test_baked_occluders_match_runtime_build` checks count, triangles, and extent against the runtime build.

## Performance experiments (debug and Release Perf builds)

Temporary settings layered on top of a profile for measurements. They run in debug builds and in release builds exported with the `perf_bench` custom feature (see "Build features"); normal release builds ignore them. With no experiment and the "none" profile the game runs with scene defaults (`test_no_perf_experiment_by_default`).

- **Flags:** `PerfConfig` (`game/debug/perf_config.gd`) holds one experiment, parsed from JSON; unknown keys, categories, or profiles are rejected. Keys: `experiment`, `profile` (`none`/`high`/`low`; omitted = platform default), the `RenderSettings` keys `hide` (categories), `visibility_end` ({category: metres}), `camera_far` + `fog`, `shadows` (`default`/`off`/`single`), `render_scale` + `scaling_mode` (`bilinear`/`metalfx`; FSR is Forward+ only in Godot 4.7.2), `max_fps`, `occlusion`, `lod_threshold`, a `runtime` section (below), and an optional `bench` section (`warmup_s` 30, `measure_s` 60, `views`, `session_minutes`, `session_view`, `screenshots`, `quit_when_done`, `in_vehicle`). Experiments from the 2026-10-24 diagnosis pin `"profile": "none"`, the condition they were measured under; Phase 4 experiments (`c_*`, `pacing_*`, `jolt_*`, `session_pacing_*`) name the device profile (`low` tablet, `high` iPhone).
- **Runtime keys** (`PerfConfig.RUNTIME_KEYS`, applied by `Main.apply_runtime_settings()`, measurement only): `physics_ticks` (Engine physics rate), `physics_interpolation`, `player_physics` (false pauses the player's `_physics_process`, so no `move_and_slide`), `vehicles` (false takes the parked vehicles out of the simulation), `collider_radius` (map static bodies whose ground-plane bounds are farther than this from the player are disabled and leave the physics space; re-evaluated at each viewpoint; 0 = all off, which needs `player_physics: false`), `vsync_mode` (`disabled`/`enabled`/`adaptive`/`mailbox`), `vehicle_sleep` (false keeps parked vehicles awake, Phase 4b A/B; applied to a copy of each vehicle's definition). Keys an experiment leaves out keep their defaults; the result's `config.runtime` records them.
- **Applying:** `game.apply_perf_experiment()` merges the experiment over its profile and applies it through the same `RenderSettings`; there is no separate experiment code path.
- **Categories** (by node-name prefix, checked in this order; every one of the 3,055 map meshes matches one, enforced by `test_perf_categories_cover_every_map_mesh`; defined in `RenderSettings.CATEGORIES`):

  | Category | Prefixes | Mesh nodes | Triangles (LOD0, from the GLB) |
  |---|---|---|---|
  | facade_detail | `Detail_`, `MosqueDetail_`, `LandmarkDetail_` | 371 | 4,536,517 (64.2 %) |
  | decor | bridge details and glass, `RoadPaint_`, `TrafficSignals_`, `SignalGlow_`, `Ferry_` | 299 | 159,048 (2.2 %) |
  | lamps | `StreetLamps_`, `LampGlow_` | 517 | 305,368 (4.3 %) |
  | trees | `Trees_`, `TreeTrunks_`, `Shrubs_` | 465 | 1,246,592 (17.6 %) |
  | buildings | `Buildings_`, `Mosque_`, `Landmark_` | 371 | 144,716 (2.0 %) |
  | ground | `Ground_`, `Road_`, `Pavement_`, `Quays_`, `Gardens_`, bridge decks | 1,031 | 678,214 (9.6 %) |
  | water | `Water` | 1 | 2 |

- **Loading:** `game.gd` reads `--perf-config=<path>` from the command line (desktop) or a one-shot `perf_bench.json` (devices; deleted when read) from `user://`, or on Android from the app-specific external folder `OS.get_system_dir(SYSTEM_DIR_DOCUMENTS, false)` (`/sdcard/Android/data/<package>/files/Documents`): a release APK is not debuggable, so `run-as` cannot reach `user://`, but adb reaches that folder directly. Experiment definitions live in `tools/perf/experiments/*.json`.
- **Benchmark:** `PerfBenchmark` visits each viewpoint, waits `warmup_s`, then records every frame time for `measure_s`: average FPS (frames / time), 1 % low (FPS at the 99th-percentile frame time), minimum FPS (longest frame), frame-time percentiles (`frame_p50_ms`, `frame_p90_ms`, `frame_p99_ms`), a 1 ms histogram (`frame_hist_ms`, 0–99 ms plus one bin for longer frames), `long_frames` (over 1.25 × the median, i.e. at least one display refresh late), the physics step and process times (`physics_ms`/`physics_p99_ms`, `process_ms`/`process_p99_ms`: `Performance.TIME_PHYSICS_PROCESS` and `TIME_PROCESS` sampled every frame), and per-second averages of draw calls, primitives, and objects, plus peak video memory and engine static memory, and `vehicles_asleep` (share of frames in which the map's vehicles slept). Each result records the active profile and `in_vehicle`; the results file also has `startup` with the build kind and frame/physics settings (`debug_build`, `perf_feature`, `physics_ticks`, `physics_interpolation`, `max_fps`, `vsync_mode`, `screen_refresh_rate` (panel maximum), `display_refresh_rate` (the rate frames are paced to), `ios_allow_high_refresh_rate`, `android_frame_pacing`) and the vehicles' sleep state at the first frame (`vehicles`). It logs `BENCH {json}` lines, writes `user://bench_results.json` (with the profile, the occluder source and load time, and the startup times), saves 640 px JPEG screenshots to `user://bench/`, then quits (Android) or hides the map and drops to 5 FPS until the host terminates it (iOS ignores `quit()`).

### Measurement protocol and host scripts

```bash
# Android (debug APK installed; do not run Godot --import/--export meanwhile: the editor stops adb on exit)
tools/perf/run_batch.sh android build/perf/android tools/perf/experiments/baseline.json ...
# iOS (debug app installed; Auto-Lock off)
IOS_UDID=<udid> tools/perf/run_batch.sh ios build/perf/ios tools/perf/experiments/baseline.json ...
python3 -I tools/perf/summarize.py build/perf/android   # Markdown tables
# From Phase 3 on: at least three runs per device and viewpoint, one output folder per run
for run in run1 run2 run3; do tools/perf/run_batch.sh android build/perf/<task>/android/$run tools/perf/experiments/profile_default.json ...; done
python3 -I tools/perf/median.py build/perf/<task>/android/run1 build/perf/<task>/android/run2 build/perf/<task>/android/run3
```

- **Repeats (from 2026-10-25):** at least three runs per device, experiment, and viewpoint; report the median, with every run's value next to it (`tools/perf/median.py`). Identical single runs differed by 2–3 FPS in the tablet's 1 % low.
- Results also record the physics step time (`physics_ms`, `physics_p99_ms`: `Performance.TIME_PHYSICS_PROCESS` sampled every frame; it reports one 60 Hz step, so at a 30 FPS cap a frame contains two) and whether the run was in a vehicle (`in_vehicle`; `profile_default_vehicle`, `session_profile_vehicle`: the player sits in the map's first vehicle, moved to each viewpoint, no pedal pressed).

- Cold start for every run. Android: the batch waits until the battery is back to its starting temperature (+0.5 °C) and keeps the screen on while plugged in (`svc power stayon usb`, restored afterwards). iOS: each run waits for the Instruments thermal state "Nominal".
- Unlock both devices before a batch. The Android script only wakes the screen; behind a PIN lock screen the app never comes to the foreground and the run times out (40 min) without results. iOS needs Auto-Lock off: a locked iPhone makes every Instruments probe answer "Waiting for device to boot". `ios_bench.sh` first queries the device with `devicectl` (that restored the connection when it showed "available (paired)"), stops after three probes without a thermal state, and tolerates a single probe or process-list dropout.
- Per viewpoint (Spawn, Karaköy, Galata): 30 s warm-up, 60 s measurement. The app is closed between runs.
- Recorded per run: Android battery temperature and thermal status at start and end, the cool-down wait before the run (`cool_wait_s`, target `cool_target_c`), peak PSS (`dumpsys meminfo` every 15 s); iOS thermal state and app physical footprint from 3 s "Activity Monitor" probes every ~45 s (`tools/perf/parse_xctrace.py`). A run that reaches "Serious" on iOS is invalid.
- The probes themselves add load. On the tablet, `dumpsys meminfo` every 15 s causes single 100+ ms frames, which lowers the minimum FPS (average unaffected); set `SAMPLE_PSS=0` for frame-pacing measurements. On iOS an Instruments session runs for 3 s of every ~45 s.
- Results, conditions, and screenshots of the 2026-10-24 pass are kept in `docs/perf/` (`results/<device>/<experiment>.json` and `.meta.json`; 480 px screenshots); the profile validation in `docs/perf/profiles/`, the Phase 2 regression in `docs/perf/phase2/`. Regenerate the tables with `python3 -I tools/perf/summarize.py docs/perf/results/android --compact` (or the other `results/<device>` folders).
- Renderer comparison: Android uses the "Android Debug Compatibility" preset (`--rendering-method gl_compatibility` embedded); iOS passes the same argument at launch (`APP_ARGS`).

## Build features

`BuildFeatures` (`game/debug/build_features.gd`) decides what a build may do beyond gameplay:

| Build | Debug overlay, VIEW/Q/DUMMY/CAR | Experiments, benchmark, STARTUP log |
|---|---|---|
| Debug (editor, debug export templates) | yes | yes |
| Release with custom feature `perf_bench` (the `* Release Perf*` presets only) | no | yes |
| Normal release | no | no |

Tests force both answers with `BuildFeatures.debug_override` / `perf_feature_override` (`test_build_features.gd`, `test_release_perf_build_runs_benchmarks_without_debug_ui`, `test_normal_release_ignores_experiments`). `test_perf_bench_only_in_release_perf_presets` reads `export_presets.cfg`: only presets named "… Release Perf …" carry `perf_bench`, keystore fields are empty, and no option holds a personal path.

Measurement-only variants use feature-tagged project overrides, resolved at runtime when the export carries the tag: `physics/3d/physics_engine.perf_jolt="Jolt Physics"` ("Android Release Perf Jolt"). Normal runs keep `DEFAULT` (GodotPhysics3D) (`test_measurement_overrides_do_not_touch_defaults`, `test_measurement_tags_only_in_their_presets`). The Phase 4a "iOS Release Perf 60Hz" preset and its `perf_60hz` override were removed in Phase 4b: 60 Hz is now the default for every iOS build (D20), so the preset would build the same app as "iOS Release Perf"; its results stay in `docs/perf/phase4a/results/ios_60hz/`.

## Device builds (debug)

Never upload to a store, TestFlight, or Play Console from these steps.

```bash
# Android: arm64 APK signed with the Godot editor's debug keystore (local editor settings)
godot --headless --path . --export-debug "Android Debug" build/android/map-simulator-debug.apk
adb install -r build/android/map-simulator-debug.apk

# iOS: Xcode project export + xcodebuild WITHOUT -allowProvisioningUpdates (no portal changes)
tools/build_ios_debug.sh               # build only
tools/build_ios_debug.sh <device-udid> # build and install with devicectl
```

- Identifiers: Android `com.mirongi.mapsimulator`; iOS debug `com.mirongi.mapsimulator.dev` on the temporary team in `export_presets.cfg`. The final iOS ID `com.mirongi.mapsimulator` must not be registered from this Mac (`PROJECT_CONTEXT.md` D8–D9).
- Requirements: Godot 4.7.2 export templates; Android SDK, JDK, and debug keystore configured in the Godot editor settings; Xcode with a signing identity and a matching team profile.
- The imported map is about 195 MB of the 224 MB APK.

### Release Perf builds (measurement only)

```bash
# Android release-template APK, signed with the editor's debug keystore via GODOT_ANDROID_KEYSTORE_RELEASE_*
# (read from the editor settings; macOS path by default, GODOT_EDITOR_SETTINGS=<file> elsewhere)
tools/build_android_perf.sh                                     # "Android Release Perf"
tools/build_android_perf.sh "Android Release Perf Jolt" build/android/map-simulator-release-perf-jolt.apk
# iOS Xcode Release configuration, automatic signing WITHOUT -allowProvisioningUpdates
tools/build_ios_perf.sh "iOS Release Perf" <device-udid>
```

- Release templates: the Android APK is not debuggable (`run-as: package not debuggable`); the iOS app links the template's `libgodot.ios.release.xcframework`. `STARTUP … build={"debug_build":false,"perf_feature":true,…}` and every result file's `startup.debug_build` prove it.
- The keystore path and password come from the local editor settings at build time and never enter the repository. This is not a release signing setup; nothing is uploaded anywhere.
- Same package / bundle ID as the debug builds, so installing one replaces the other.

## Conventions

- One `class_name` per reusable module; `##` doc comments at the top of each script; tabs for indentation.
- Scenes are `.tscn` text files; shared tunables live in resources (`CameraProfile`, `MapDefinition`).
- Commit the `.uid` files Godot generates next to scripts.
- Exported script properties use `Array[String]`, not `PackedStringArray`: Godot 4.7.2's export conversion of `.tres` files dropped an exported `PackedStringArray`. `test_no_packed_string_array_exports` enforces this.
