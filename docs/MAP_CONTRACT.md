# Map Contract

What a map model (GLB) must and should provide so that the game can play on it without hand work: the player walks, punches, and rolls, the car drives, NPCs patrol, and the quality profiles apply. The import tool (`tools/import_map.gd`) checks every rule below, fixes what it can, and writes a report that names each failed rule and how to fix it. Decision: `PROJECT_CONTEXT.md`, D26.

Each rule has an id. The tool's report lists every id with one result:

| Result | Meaning |
|---|---|
| PASS | The rule holds. |
| FIXED | The rule did not hold and the tool fixed it (automatically, or because the configuration asked for it). |
| WARN | The rule does not hold; the map still works, with the consequence named in the message. |
| FAIL | The rule does not hold and the tool cannot fix it alone. The report says what to change; the map is not written or registered until it passes (or `--force` is given). |
| INFO | A measurement, no rule. |

## Units, axes, and categories

- 1 unit = 1 metre; +Y is up; forward is −Z (glTF and Godot conventions).
- Every mesh belongs to at most one **category**, the vocabulary the quality profiles understand:

| Category | What it is | What the game does with it |
|---|---|---|
| `ground` | terrain, roads, pavements, squares, bridge decks | walkable; collider (trimesh) when the map has no collision nodes; occluder source |
| `buildings` | building shells, walls, roofs, towers, domes | collider (convex per part) when the map has no collision nodes; occluder source |
| `facade_detail` | windows, doors, timber, trims, balconies | no collider; visibility range in the low (100 m) and high (200 m) profiles |
| `trees` | trees, bushes, hedges | no collider; visibility range |
| `lamps` | street lamps and their glows | no collider; visibility range |
| `decor` | signs, fences, benches, props, small details | no collider; visibility range |
| `water` | water surfaces | no collider (a player who walks in falls and respawns) |

A mesh in no category keeps the scene's defaults (always drawn, no collider) and is listed in the report.

## Mandatory rules

| Id | Rule | How the tool checks it | Message when it fails | Fix |
|---|---|---|---|---|
| C1 | The file is a glTF 2.0 scene (`.glb` or `.gltf`) that Godot loads, with at least one triangle mesh. | `GLTFDocument.append_from_file()` returns OK and the scene has a `MeshInstance3D` with triangles. Line and point primitives are skipped (WARN). | `C1 FAIL: <file> is not a glTF 2.0 file Godot can load (error <n>)` / `C1 FAIL: no triangle mesh in <file>` | Export the model as glTF 2.0 binary from the modelling tool. |
| C2 | 1 unit = 1 metre. | The horizontal extent of all geometry (larger of X and Z) is between 20 m and 10,000 m. The 90th percentile of the meshes' heights is reported, and a height outside 1.5–300 m is a WARN. | `C2 FAIL: the model spans <w> × <d> units; with 1 unit = 1 m that is not a map. If it is in other units, set "scale" in the configuration (suggested: <s>, which makes its typical object <h> m tall).` | `"scale": <s>` in the configuration (FIXED). The suggestion scales the 90th-percentile mesh height to 8 m. |
| C3 | +Y is up. | Area-weighted face orientation: the area of faces within 30° of +Y must be at least half the area within 30° of +Z and at least half the area within 30° of −Y. | `C3 FAIL: most flat area faces <+Z/−Y>, not +Y: the model looks <Z-up/upside down>. Set "up_axis": "z" in the configuration (or re-export with +Y up).` | `"up_axis": "z"` rotates a Z-up model to Y-up (FIXED). |
| C4 | There is walkable ground. | After the colliders exist: rays straight down on a grid over the map (spacing extent / 100, between 2 and 10 m); a sample is walkable when its first hit is a `ground` collider no steeper than 35°. At least 5 % of the samples must be walkable. | `C4 FAIL: only <n> % of the map has walkable ground (a ground collider no steeper than 35°). Name the ground meshes (R1) or add collision nodes (R2).` | Category names or rules for the ground meshes (R1), or `-col` nodes (R2). |
| C5 | Coordinates stay where single-precision floats are exact enough. | Every vertex within 20 km of the origin; vertical extent at most 2 km. | `C5 FAIL: geometry reaches <d> m from the origin (limit 20 km) / spans <h> m vertically (limit 2 km). Move the model's origin into the map.` | Re-export with the origin inside the map. |
| C6 | Triangle budget. | Total triangles of all meshes: at most 10,000,000 (FAIL); more than 2,000,000 is a WARN (beyond what the tablet class draws comfortably even with the low profile). | `C6 FAIL: <n> triangles (limit 10,000,000)` / `C6 WARN: <n> triangles, above the 2,000,000 mobile budget: the low profile hides only categorized meshes beyond 100 m; lighter geometry or more meshes in visibility-range categories would help.` | Lighter geometry; categories for detail meshes. |
| C7 | Closed, one-sided geometry: building meshes are closed shells whose triangles face outward; a triangle's winding agrees with its normal; no zero-area triangles. | On every `buildings` mesh of at most 50,000 triangles (positions welded at 1 mm): the share of edges used by only one triangle, and the signed volume (negative = inside out). On every mesh with normals: the share of triangles whose winding disagrees with their normals. On every mesh: zero-area triangles (area below 10⁻⁶ m²). Violations are WARN: the game still works because building colliders are convex hulls and normals are recomputed where missing. | `C7 WARN: <n> of <m> building meshes are open (more than 5 % boundary edges), e.g. <names>: open walls show holes with back-face culling, and colliders fill the convex hull.` / `C7 WARN: <n> building meshes are inside out (negative volume)` / `C7 WARN: <n> triangles disagree with their normals` / `C7 WARN: <n> zero-area triangles` | Close and orient the shells in the modelling tool (Blender: Mesh → Clean Up, Normals → Recalculate Outside). |
| C8 | There is room to play: a player spawn, a vehicle place, and an NPC route. | See "Placement" below. | `C8 FAIL: no player spawn: needs a walkable point (ground, at most 20°) with a 2 m clear circle and 20 m of clear walk ahead.` / `C8 FAIL: no vehicle place: needs a clear flat area of 7 m × 5 m (heights within 0.3 m, at most 8°) with 25 m of clear road ahead.` / `C8 FAIL: no NPC route: needs two walkable points 8–16 m apart, at least 10 m from the spawn, with a clear path between them.` | Give the point in the configuration (`"spawn"`, `"vehicle_spawn"`, `"npc_route"`), or open up the geometry (C4, C7). |

## Recommended rules

| Id | Rule | How the tool checks it | Message | Fix |
|---|---|---|---|---|
| R1 | Mesh names say what a mesh is (a category word or prefix), or the configuration maps names or materials to categories. | Every mesh goes through the category rules in order: the configuration's `category_rules`, then the default name vocabulary (below), then geometry (below). The report counts each way and lists the meshes geometry classified or left out. | `R1 WARN: <n> meshes matched no name rule and were classified by their shape (<counts>); <k> are in no category: <names>` | Names or `category_rules` (FIXED by geometry where it can). |
| R2 | Collision is given by collision nodes, Godot's naming convention: `<name>-col` (mesh plus trimesh collider), `-colonly` (trimesh collider, no mesh), `-convcol`, `-convcolonly` (convex). | Node names. When the model has any collision node, only those are used. Otherwise colliders come from the categories: `ground` trimesh per mesh, `buildings` one convex hull per connected part (parts smaller than 0.5 m are skipped), nothing for the others; `"colliders"` in the configuration changes this per category (`trimesh`, `convex`, `box`, `none`). | `R2 INFO: no collision nodes; colliders generated from the categories: <counts>` | Collision nodes in the model, or `"colliders"`. |
| R3 | Separate objects: one mesh per building or block, not the whole city in one mesh; no non-ground mesh wider than 150 m. | Horizontal extent of every non-ground mesh. | `R3 WARN: <n> non-ground meshes are wider than 150 m (<names>): visibility ranges and occlusion work per mesh, so they are drawn whole or not at all.` | Split the model into objects. |
| R4 | Every mesh has normals. | The glTF primitives' `NORMAL` attribute. | `R4 FIXED: <n> meshes had no normals; flat normals computed from the triangles` | Automatic: flat (per-face) normals. |
| R5 | Colour comes from textures or vertex colours. | Materials: a white, untextured material on a mesh with vertex colours does not show them in Godot. | `R5 FIXED: <n> materials show their vertex colours now` / `R5 WARN: <n> white untextured materials without vertex colours render white` | Automatic for vertex colours. |
| R6 | Materials are single-sided. | Materials whose cull mode is disabled (glTF `doubleSided`). | `R6 WARN: <n> double-sided materials: back faces are drawn too (fill-rate cost on mobile). Set "single_sided": true if the shells are closed (C7).` | `"single_sided": true` (FIXED). |
| R7 | Water is a separate mesh named `water` (or mapped by a rule). | Category counts. | `R7 INFO: <n> water meshes` | Name or rule. |
| R8 | The model holds only meshes. | Lights, cameras, skeletons, and animations in the scene are removed (the map scene brings its own sun and sky). | `R8 INFO: removed <n> lights, <m> cameras, <k> animation players` | — |

### Default name vocabulary (R1)

Applied after the configuration's rules, case-insensitively: a line matches when any word of the node name starts with one of its words (words are separated by anything that is not a letter and by a lowercase letter followed by an uppercase one, so `osm_12_walls` matches `wall`, `road-sign-stop` matches `sign`, and `StreetLamps_3` matches `lamp`). The first matching line wins:

| Category | Words |
|---|---|
| `water` | water, sea, river, lake, pond, ocean |
| `decor` | traffic, sign, fence, barrier, bench, cone, dumpster, bin, hydrant, mailbox, pole, wire, planter, prop, car, vehicle |
| `lamps` | lamp, light, lantern |
| `trees` | tree, bush, shrub, hedge, plant, foliage, vegetation, palm, leaves |
| `facade_detail` | window, door, balcony, timber, beam, trim, cornice, facade, shutter, awning, railing, detail, frame |
| `buildings` | building, house, wall, roof, tower, dome, drum, minaret, chimney, church, mosque, shop, skyscraper, apartment, office |
| `ground` | ground, terrain, road, street, pavement, sidewalk, path, grass, land, landcover, floor, plaza, square, tile, parking, driveway, curb, kerb, dirt, sand, field, bridge |

`"use_default_name_rules": false` in the configuration turns the vocabulary off.

### Geometry classification (R1)

For meshes no name rule matched, from the mesh's box in the map (after scale and axis fixes) and its faces, in this order:

1. `ground`: wider than 20 m, at most a quarter as high as wide, and at least half of its area faces up (within 30° of +Y).
2. `buildings`: at least 2.5 m high, at least 2 m wide in both directions, and at least a quarter of its area vertical (within 30° of horizontal normals).
3. `decor`: smaller than 2.5 m in every direction.
4. Otherwise no category (`default_category` in the configuration, empty by default).

The tool stores this result in the map (each such mesh is in the Godot group `map_category_<category>`), and the map's category rules end with one rule per group, so the game sees the same categories the report shows.

## Placement (C8)

The tool places what gameplay needs with physics queries against the generated colliders:

| Item | Requirements | Choice among the candidates |
|---|---|---|
| Player spawn | The first hit of a ray down is a `ground` collider at most 20° steep; the player's capsule (radius 0.35 m, 1.8 m) fits there; no collider within 2 m between 0.5 and 2.0 m above the ground; at least 20 m of clear walk in the spawn's direction (1 m steps: ground under each step, a height change of at most 0.5 m per step, the capsule fits). | The candidate closest to the centre of the walkable area among those with the longest walks (capped at 40 m); it faces its longest walk. |
| Vehicle | A 7 m × 5 m area (the car plus room to get out on either side) with no collider between 0.3 and 2.5 m above the ground; ground under its corners and centre within 0.3 m in height and at most 8° steep; at least 25 m of clear road ahead (a 3 m wide box between 0.3 and 1.8 m above the ground every 2 m, ground under it, at most 0.6 m height change per 2 m); its centre at least 8 m from the spawn and 6 m from the spawn's walk. | The candidate with the longest drive (capped at 40 m), then the one closest to the spawn; it faces its drive. Placed 0.3 m above the ground. |
| NPC route | Two points 8–16 m apart (12 m tried first) on walkable ground, at least 10 m from the spawn, 6 m from the spawn's walk, and 4 m from the vehicle's drive; the capsule fits every 1 m along the path, with ground under it (height change at most 0.5 m per step). | The route closest to the spawn; the NPC waits 1.5 s at each point. |
| Viewpoints | Three walkable points with a 2 m clear circle, at least 30 m apart (fewer is a WARN), each facing the centre of the map. | The best-scored spawn candidates. |
| A sloped viewpoint | A vehicle place (as above, without the drive) on ground between 2° and 10° steep, for the device scenario's parked-on-a-slope steps. | Optional (INFO when none). |
| Bounds | The extent of the walkable samples, 1 m inside. | — |
| Kill height | 10 m below the lowest geometry. | — |

Positions in the configuration (`"spawn"`, `"vehicle_spawn"`, `"npc_route"`) replace the search for that item.

## Configuration (optional JSON)

Every key is optional; the tool works without a configuration file.

| Key | Default | Meaning |
|---|---|---|
| `id` | from the file name | Registry id (`[a-z0-9_]`); the folder is `maps/<id>/`. |
| `display_name` | the id | Name in the debug overlay. |
| `scale` | 1 | Uniform scale applied to the whole model (C2). |
| `up_axis` | `"y"` | `"z"` for a Z-up model (C3). |
| `single_sided` | false | Back-face culling on every material (R6). |
| `category_rules` | [] | Ordered rules before the vocabulary: `{"category": "<category>", "prefix" \| "regex" \| "words" \| "material" \| "group": "<pattern>"}`; `prefix` is the start of the node name, `regex` searches the node name, `words` is a space-separated word list matched as in the vocabulary, `material` searches each surface's material name (regex), `group` a Godot group. |
| `category_rules_resource` | — | A `CategoryRules` resource (`.tres`) to use as the rules instead (the vocabulary and geometry still follow). |
| `use_default_name_rules` | true | The default vocabulary (R1). |
| `default_category` | `""` | Category for meshes nothing classifies. |
| `colliders` | ground trimesh, buildings convex | Collider type per category: `trimesh`, `convex`, `box`, `none` (R2). With collision nodes in the model: `"colliders": "auto"` adds the category colliders to them. |
| `spawn` | searched | `{"position": [x, y, z], "yaw": degrees}` |
| `vehicle_spawn` | searched | `{"position": [x, y, z], "yaw": degrees}` |
| `npc_route` | searched | `[[x, y, z], [x, y, z], …]` |

## What the tool writes

| File | Contents | In Git |
|---|---|---|
| `maps/<id>/<id>.tscn` | The map scene: the model, a `WorldEnvironment` and a `DirectionalLight3D` named `Sun` (the profiles change fog and shadows on them). | yes |
| `maps/<id>/<id>_model.scn` | The processed model: meshes with fixes, colliders on physics layer 1. | only when smaller than 10 MB; otherwise listed in `required_files`, regenerated on each machine, ignored by Git |
| `maps/<id>/<id>.tres` | The `MapDefinition`: spawn, bounds, kill height, vehicle spawn, NPC route, viewpoints, occluders, category rules, required files. | yes |
| `maps/<id>/<id>_categories.tres` | The `CategoryRules`. | yes |
| `maps/<id>/<id>_occluders.scn` | Occluders baked from the `buildings` and `ground` colliders (`RenderSettings.build_occluders`). | yes |
| `docs/maps/imported/<id>.md` | The report. | yes |
| `game/world/maps.tres` | The map appended to the registry (selectable in debug and Release Perf builds; the default does not change). Skipped with `--no-register`. | yes |

## Adding a map (user steps)

1. Put the GLB anywhere on disk (it is read, never copied or changed).
2. Optionally write a configuration JSON (above).
3. Run:

   ```bash
   godot --headless --path . --script res://tools/import_map.gd -- --glb=/path/to/map.glb [--config=/path/to/map.json] [--id=<id>]
   ```

4. Read the report (`docs/maps/imported/<id>.md`): every FAIL names the change to make; fix it in the model or the configuration and run the command again.
5. In a debug build, press MAP until the overlay names the map, or start with `--map=<id>`.
