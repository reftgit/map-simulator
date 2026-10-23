# PROJECT_STATE.md — Verified Current State

What actually exists in the repository and how it was verified. Plans and decisions belong in `PROJECT_CONTEXT.md`.

Last updated: 2026-10-24 (Phase 0, Claude Code)

## Current phase

**Phase 0 — project audit.** The İstanbul • Haliç map project has been copied into the repository unchanged and validated on Godot 4.7.2. No game code exists yet.

## Current objective

Phase 1: a character that walks and runs on the map with a touch joystick and a touch-controlled third-person camera.

## Git

- Branch: `main`. Remote: `origin` → `https://github.com/reftgit/map-simulator.git`. Upstream: `origin/main`.
- `3c0771c`: development protocol bootstrap (documentation only).

## Repository contents

| Path | Notes |
|---|---|
| `project.godot` | Original map project settings: Godot 4.4 features, GL Compatibility renderer, 1440×900 viewport, main scene `main.tscn`. |
| `main.tscn`, `scripts/main.gd`, `scripts/explorer.gd` | Original explorer demo: keyboard/mouse fly and walk camera, HUD, mosque labels. Desktop only. |
| `scripts/water.gdshader` | Original water shader. |
| `assets/istanbul_halic.glb` | Map model, 502 MB. **Not tracked** (`.gitignore`); restore steps in `docs/maps/istanbul_halic/README.md`. |
| `assets/istanbul_halic.glb.import`, `assets/map_metadata.json` | Import settings (LOD and shadow meshes on) and map metadata (spawn, bounds, mosques, lamps). |
| `docs/maps/istanbul_halic/` | Map origin, restore steps, key coordinates, original map docs and attribution. |
| `tests/map/validate_scene.gd` | Original map validation script, unchanged. |
| `.vscode/settings.json` | The user's editor color settings. Untracked, intentionally not committed. |

## Phase 0 audit findings

- Engine: Godot 4.7.2.stable.official (`/opt/homebrew/bin/godot`). Export templates 4.7.2.stable are installed.
- Map: about 7.07 M triangles, 14.8 M vertices, 3,055 mesh nodes, 9,001 buildings, 5,477 trees, 4,008 street lamps (`source/statistics.json` in the source package). The GLB's JSON header lists 6 materials (3 emissive, 3 double-sided, all opaque), 0 images, and 0 textures, so texture memory is not a cost; geometry is.
- Collision: `-col` suffix nodes become 827 `StaticBody3D` nodes on import (layer 1). Decor and water have no collision.
- No character model, animations, or vehicle models exist.
- Original scripts: `explorer.gd` is a keyboard/mouse inspection controller (fly and walk modes). `main.gd` builds the sky, a 4-split directional shadow with 450 m distance, water material, HUD, and mosque labels at runtime.
- Toolchains present: Xcode 27.0, Android SDK at `~/Library/Android/sdk`, JDK 17 configured in Godot editor settings, Android debug keystore. No `export_presets.cfg` exists.
- Devices visible on 2026-10-24: one paired physical iPhone 13 Pro (`xcrun devicectl`) and one Android device (`adb devices`). Nothing was installed on them.

## Implemented features

None of the game. Only the original explorer demo exists.

## Verified behaviors

| Behavior | Evidence |
|---|---|
| Copied files are identical to the source package. | 2026-10-24: SHA-256 of all 11 copied project files and `validate_scene.gd` match the package's `manifest.sha256`. |
| The map imports on Godot 4.7.2. | 2026-10-24: `godot --headless --path . --import` exit 0 in 15.6 s, peak memory about 3.3 GB, no errors or warnings in the log; `project.godot` unchanged. |
| The original map validation passes on 4.7.2. | 2026-10-24: `godot --headless --path . --script res://tests/map/validate_scene.gd` → `VALIDATION PASS | failures=0`, `STATIC_COLLIDERS 827`, spawn floor `(-109.0365, 4.547554, 204.2572)` on Galata Bridge collision; identical to the package's Godot 4.4.1 record. |
| Claude Code loads `AGENTS.md` through `CLAUDE.md`. | 2026-10-23: `claude -p --tools ""` answered rules found only in `AGENTS.md`. |

## Unverified behaviors

- Rendering performance of the map on any phone or tablet: never measured.
- Codex reading `AGENTS.md`: not tested.

## Known bugs and regressions

None recorded.

## Technical risks

- Map weight: 7.07 M triangles is far beyond typical mobile budgets even with LODs.
- A fresh clone lacks the GLB and will not run until it is restored.
- `.vscode/` is untracked and not ignored; stage files by explicit path.

## External blockers

None for Phase 1.

## Required manual actions

- Provide or choose character and car models (open questions 1–2 in `PROJECT_CONTEXT.md`).

## Current priorities

1. Phase 1: mobile character control.
2. Then wait for review and user approval before Phase 2.

## Recommended next task

Implement Phase 1 as described in `PROJECT_CONTEXT.md`.
