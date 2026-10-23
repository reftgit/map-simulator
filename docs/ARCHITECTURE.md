# Architecture

How the game code is organized and how to extend and test it. Implementation status lives in `PROJECT_STATE.md`; decision rationale lives in `PROJECT_CONTEXT.md`.

Engine: Godot 4.7.2, GDScript with static typing. 1 unit = 1 m; forward is -Z.

## Directory layout

```text
game/
  main.tscn, game.gd        Composition root (main scene)
  world/                    WorldManager, MapDefinition
  player/                   PlayerController, PlayerIntent, input sources, player.tscn
    state_machine/          PlayerStateMachine, PlayerState, Idle/Walk/Run states
  camera/                   ThirdPersonCamera, CameraProfile, on-foot profile
  input/                    MobileInputController, TouchControl, TouchLookArea, TouchButton
  ui/                       UIController, hud.tscn
maps/<map_name>/            One folder per map: scene, MapDefinition (.tres), map script
assets/                     Map model and metadata (the 502 MB GLB is not in Git)
scripts/, main.tscn         Original explorer demo from the map package (desktop only, not used by the game)
tests/                      Headless test runner, unit and integration suites, fixtures
tools/                      Development tools (screenshot capture)
docs/                       This file, map documentation
```

## Runtime structure

```text
Main (game.gd) ─ wires everything once in _ready()
├── WorldManager          loads maps/<map>/<map>.tscn from a MapDefinition; respawn and bounds
│   └── IstanbulHalic     map scene: GLB, sky/ambient, sun, water shader, vertex-color fix
├── Player                PlayerController (CharacterBody3D, layer 2)
│   └── StateMachine      Idle, Walk, Run (child nodes)
├── ThirdPersonCamera     top-level rig → PitchPivot → SpringArm3D → Camera3D
├── TouchPlayerInput      PlayerInputSource: stick + camera yaw → PlayerIntent
└── HUD                   UIController (CanvasLayer): safe area, debug overlay
    └── SafeArea/Controls MobileInputController
        ├── LookArea      TouchLookArea (right 58 %)
        ├── Joystick      native VirtualJoystick (left 42 %), drives move_* actions
        └── RunButton     TouchButton, toggle
```

Systems do not search for each other. `game.gd` is the only place that connects them.

## Per-frame data flow

1. **Touch.** The native `VirtualJoystick` writes the `move_left/right/forward/back` actions. `MobileInputController._input()` routes every other touch to one `TouchControl` in priority order (run button, then look area) and owns that finger until release. A finger that starts on the look area keeps turning the camera even if it slides over a button. Unclaimed touches fall through to the GUI, where the joystick takes them.
2. **Camera (`_process`).** `ThirdPersonCamera` consumes the look delta (radians), clamps pitch, follows the target's interpolated transform, and lets the `SpringArm3D` (sphere, world layer) pull the camera in front of walls.
3. **Player (`_physics_process`).** `PlayerController` clears its `PlayerIntent` and asks its `input_source` to fill it. `TouchPlayerInput` rotates the stick by the camera yaw (`camera_relative`). The active `PlayerState` picks the target speed and transitions, `apply_locomotion()` accelerates, turns the body, and applies gravity, then `move_and_slide()` runs.
4. **World (`_physics_process`).** `WorldManager` respawns tracked bodies below `kill_height` and clamps them to `bounds`.

## Module map

The specification suggested these modules. Status as of Phase 1:

| Module | Implementation | Status |
|---|---|---|
| PlayerController | `game/player/player_controller.gd` | Phase 1 |
| PlayerStateMachine | `game/player/state_machine/` | Phase 1: Idle, Walk, Run |
| ThirdPersonCamera | `game/camera/third_person_camera.gd` + `CameraProfile` | Phase 1 |
| MobileInputController | `game/input/mobile_input_controller.gd` + touch controls | Phase 1 |
| WorldManager | `game/world/world_manager.gd` + `MapDefinition` | Phase 1 |
| UIController | `game/ui/ui_controller.gd` | Phase 1: safe area, debug overlay |
| PlayerCombat | not started | Phase 2 |
| PlayerAnimation | not started; will listen to `PlayerStateMachine.state_changed` | Phase 2 |
| VehicleController, VehicleInteraction | not started | Phase 3 |

## Extension points

- **New map:** add `maps/<name>/<name>.tscn` and a `MapDefinition` resource (scene path, spawn position and yaw, bounds, kill height), then point `Main.map_definition` at it. Player, camera, and input code stay unchanged.
- **New player action (punch, roll):** add a `PlayerState` child under `Player/StateMachine` and a field on `PlayerIntent`. States switch with `machine.transition_to(&"Name")`.
- **Other drivers (AI, bots, replays):** subclass `PlayerInputSource` and implement `fill_intent()`. The controller does not know where intents come from.
- **Vehicles (Phase 3 plan):** call `ThirdPersonCamera.set_target(vehicle, vehicle_profile)` with a vehicle `CameraProfile`; give the HUD a vehicle control set next to the on-foot one.
- **New touch control:** subclass `TouchControl`, add it under `HUD/SafeArea/Controls`, and register it in `MobileInputController`'s priority list.

## Physics layers

| Layer | Name | Used by |
|---|---|---|
| 1 | world | Map static bodies (GLB `-col` nodes). Mask of the player and the camera spring arm. |
| 2 | player | Player body. |

The map has collision on `Ground_*` terrain (streets included), `Buildings_*`, `Mosque_*`, `TreeTrunks_*`, landmarks, and the two bridge decks. Roads, pavements, railings, lamps, decor, and water have no collision of their own.

## Input

- Touch is primary. Several fingers work at once; each finger belongs to one control until it lifts.
- Running is a toggle button that turns off when the joystick finger lifts (`run_resets_on_release`).
- Desktop development: WASD or arrow keys move, Shift runs, and the mouse emulates touch (`emulate_touch_from_mouse`), so left-drag on the left half is the joystick and left-drag on the right half turns the camera.
- `MobileInputController` drops routed fingers when the app loses focus or pauses.

## Rendering and performance settings

- Mobile renderer on all platforms (`rendering_method` and `rendering_method.mobile`). Measured on macOS: Metal, "Forward Mobile".
- Sun: 2-split directional shadows, 60 m distance (the original demo used 4 splits and 450 m).
- Camera far plane 1500 m. MSAA 3D 2× (inherited from the map project). Physics interpolation is on (60 Hz physics, smooth on 120 Hz screens).
- Landscape (`sensor_landscape`), 1440×900 base canvas with `canvas_items` stretch and `expand` aspect, so phones get a wider canvas at 900 units tall.
- Touch sizes: joystick 220 units and run button 124 units. On an iPhone 13 Pro (1170 px landscape height, 460 ppi) that is about 95 pt / 16 mm and 54 pt / 9 mm; Apple's minimum touch target is 44 pt. Calculated, not measured on a device.

## Testing

```bash
godot --headless --path . --import                                 # after adding or renaming scripts
godot --headless --path . --script res://tests/run_tests.gd         # all suites
godot --headless --path . --script res://tests/run_tests.gd -- unit # unit suite only
godot --headless --path . --script res://tests/map/validate_scene.gd # original map validation
```

- The runner exits 0 only when every test passes. A test file that fails to load counts as a failure.
- `tests/unit/` runs without the map. `tests/integration/` loads the real map and needs `assets/istanbul_halic.glb`.
- Tests send touches through `Input.parse_input_event`, the same pipeline device touches use, with positions converted from canvas units to window pixels.
- Visual check without a device (opens a window):

  ```bash
  godot --path . --resolution 1266x585 --script res://tools/capture_screenshot.gd -- --out=/abs/path/shot.png --walk --run
  ```

  The tool prints renderer, FPS, draw calls, and primitive counts for the frame.

## Conventions

- One `class_name` per reusable module; `##` doc comments at the top of each script; tabs for indentation.
- Scenes are `.tscn` text files; shared tunables live in resources (`CameraProfile`, `MapDefinition`).
- Commit the `.uid` files Godot generates next to scripts.
