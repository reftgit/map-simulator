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
| `buildings` | building shells, walls, roofs, towers, domes | collider when the map has no collision nodes: per connected part its hull, or its own triangles when it is concave (a courtyard, an L or U plan, walls without a roof); occluder source |
| `facade_detail` | windows, doors, timber, trims, balconies | no collider; visibility range in the low (100 m) and high (200 m) profiles |
| `trees` | trees, bushes, hedges | collider when the map has no collision nodes: an upright capsule round the trunk; visibility range |
| `lamps` | street lamps and their glows | collider when the map has no collision nodes: an upright capsule round the post; visibility range |
| `decor` | signs, fences, benches, props, small details | collider when the map has no collision nodes, per part: a capsule for a pole, a box for a block or a thin barrier, its own triangles for a frame or an enclosure, none below 0.5 m or lower than 0.3 m; visibility range |
| `water` | water surfaces | no collider (a player who walks in falls and respawns) |

A mesh in no category keeps the scene's defaults (always drawn, no collider) and is listed in the report.

## Supported formats

The import tool reads glTF 2.0: `.glb`, or `.gltf` with its `.bin` and textures beside it. Other formats go through `tools/convert_to_gltf.gd` first, which writes a GLB **without changing units or axes** (so the import tool's C2 and C3 see the model as it is) and only turns the format's counter-clockwise faces into Godot's winding:

| Format | Read by | Notes |
|---|---|---|
| glTF 2.0 (`.glb`, `.gltf`) | the import tool | the native format |
| Wavefront OBJ (`.obj`) | `tools/convert_to_gltf.gd` | one node per object or group, one surface per material; MTL diffuse colour, texture, and opacity; without a material library, a PNG or JPG of the OBJ's own name beside it is its texture; polygons triangulated in their plane |
| STL (`.stl`, binary or ASCII) | `tools/convert_to_gltf.gd` | one node named after the file, no material; printed models are often Z-up and in millimetres, which C3 fixes and C2 may not see |
| FBX (`.fbx`) | `tools/convert_to_gltf.gd` (Godot's `FBXDocument`) | units and axes as Godot's FBX reader gives them |
| Blender (`.blend`), Collada (`.dae`), Unity packages | not read | export glTF 2.0 from the modelling tool |

```bash
godot --headless --path . --script res://tools/convert_to_gltf.gd -- --out=<file.glb> <input.obj|.stl|.fbx> [<input> …]
```

## Mandatory rules

| Id | Rule | How the tool checks it | Message when it fails | Fix |
|---|---|---|---|---|
| C1 | The file is a glTF 2.0 scene (`.glb`, or `.gltf` with its buffers and textures beside it) that Godot loads, with at least one triangle mesh. | `GLTFDocument.append_from_file()` returns OK and the scene has a `MeshInstance3D` with triangles. Line and point primitives are skipped (WARN). | `C1 FAIL: <file> is not a glTF 2.0 file Godot can load (error <n>)` / `C1 FAIL: no triangle mesh in <file>` | Export the model as glTF 2.0 from the modelling tool, or convert OBJ, STL, or FBX with `tools/convert_to_gltf.gd` ("Supported formats" below). |
| C2 | 1 unit = 1 metre. | After the up axis is settled (C3): the horizontal extent of all geometry (larger of X and Z) is between 20 m and 10,000 m, and the 90th percentile of the meshes' heights between 1.5 and 300 m (WARN outside). When either is off, the tool measures the model's separate objects (one per mesh, or one per connected part of a mesh that holds several objects: at least 8 parts spread over at least 4 times the largest part's footprint; flat pieces and ground-sized ones left out) and tries the common units: millimetres, centimetres, inches, feet. A unit fits when it gives a map-sized extent and a typical object (75th percentile of the objects' heights) 2–40 m tall; when exactly one fits clearly, the tool scales by it (FIXED). | `C2 FAIL: the model spans <w> × <d> units; with 1 unit = 1 m that is not a map. If it is in other units, set "scale" in the configuration (suggested: <s>, which makes its typical object, the 75th percentile of <n> separate objects, <h> m tall and <w> m wide).` / `… It looks like centimetres (0.01) or inches (0.0254): set "scale" …` / `C2 FIXED: the model looks like it is in centimetres (…): scaled by 0.01 …` | `"scale": <s>` in the configuration (FIXED; it also overrides a unit the tool chose). The suggestion makes the typical object at least 8 m tall and 8 m wide (the larger of the two scales, as streets too wide still play and too narrow do not), rounded to 1, 2, 2.5, or 5 times a power of ten. The tool cannot see units in a model of plausible size: a 255 mm relief read as 255 m stays a 255 m map. |
| C3 | +Y is up. | On the geometry as the file's nodes place it (so an exporter's axis conversion on a root node counts): the up axis is the one across which the model is flattest (its smallest extent at most half the middle one) and most flat faces lie (faces within 30° of an axis; ground and roofs), or, if those disagree, the very flat axis (at most a quarter) or the axis with twice the flat faces of any other. Which side is up: the end where flat faces gather (within 2 % of the extent: the ground, a printed relief's base) is the bottom; otherwise the side with 1.5 times the flat faces toward it; for a closed shape with both sides alike, the side whose faces lie higher. Detected +Y: PASS; another direction: the tool turns every node (rigidly) so that it points up (FIXED). When the base and the faces' winding disagree (inside out, or a flat top), or nothing shows an axis, the file's +Y is kept (WARN). | `C3 FIXED: the model is +Z up: <reason>. Rotated to +Y up ("up_axis": "y" in the configuration keeps the file's axes).` / `C3 WARN: <reason>; the file's +Y is taken as up. Set "up_axis" in the configuration if that is wrong.` | `"up_axis"`: `"y"`, `"-y"`, `"z"`, `"-z"`, `"x"`, `"-x"` (the file's direction that is up; FIXED, or PASS for `"y"`, WARN when the model looks otherwise). |
| C4 | There is walkable ground. | After the colliders exist: rays straight down on a grid over the map (spacing extent / 100, between 2 and 10 m); a sample is walkable when its first hit is a `ground` collider no steeper than 35°. At least 5 % of the samples must be walkable. | `C4 FAIL: only <n> % of the map has walkable ground (a ground collider no steeper than 35°). Name the ground meshes (R1) or add collision nodes (R2).` | Category names or rules for the ground meshes (R1), or `-col` nodes (R2). |
| C5 | Coordinates stay where single-precision floats are exact enough. | Every vertex within 20 km of the origin; vertical extent at most 2 km. | `C5 FAIL: geometry reaches <d> m from the origin (limit 20 km) / spans <h> m vertically (limit 2 km). Move the model's origin into the map.` | Re-export with the origin inside the map. |
| C6 | Triangle budget. | Total triangles of all meshes: at most 10,000,000 (FAIL); more than 2,000,000 is a WARN (beyond what the tablet class draws comfortably even with the low profile). | `C6 FAIL: <n> triangles (limit 10,000,000)` / `C6 WARN: <n> triangles, above the 2,000,000 mobile budget: the low profile hides only categorized meshes beyond 100 m; lighter geometry or more meshes in visibility-range categories would help.` | Lighter geometry; categories for detail meshes. |
| C7 | Closed, one-sided geometry: building meshes are closed shells whose triangles face outward; a triangle's winding agrees with its normal; no zero-area triangles. | On every mesh: closed and inside out when its area-weighted normals cancel out (within 1 % of its area), its volume is clearly negative, and, welded at 1 mm, at most 1 % of its edges are boundary edges; such a mesh is turned outward (winding reversed, and its normals, unless the file's normals already pointed out; FIXED). On every `buildings` mesh of at most 50,000 triangles (welded): the share of edges used by only one triangle (open when more than 5 %). On every mesh with normals: the share of triangles whose winding disagrees with their normals. On every mesh: zero-area triangles (area below 10⁻⁶ m²). The other violations are WARN: the game still works because building colliders follow concave and open shapes (R2) and normals are recomputed where missing. | `C7 FIXED: <n> closed meshes were inside out (their faces pointed in, so their outside was not drawn): turned outward` / `C7 WARN: <n> of <m> building meshes are open (more than 5 % boundary edges), e.g. <names>: open walls show holes where back faces are culled[, and their convex colliders fill the hull].` / `C7 WARN: <n> triangles disagree with their normals` / `C7 WARN: <n> zero-area triangles` | Close and orient the shells in the modelling tool (Blender: Mesh → Clean Up, Normals → Recalculate Outside). |
| C8 | There is room to play: a player spawn, a vehicle place, and an NPC route. | See "Placement" below. | `C8 FAIL: no player spawn: needs a walkable point (ground, at most 20°) with a 2 m clear circle and 20 m of clear walk ahead.` / `C8 FAIL: no vehicle place: needs a clear flat area of 7 m × 5 m (heights within 0.3 m, at most 8°) with 25 m of clear road ahead.` / `C8 FAIL: no NPC route: needs two walkable points 8–16 m apart, at least 10 m from the spawn, with a clear path between them.` | Give the point in the configuration (`"spawn"`, `"vehicle_spawn"`, `"npc_route"`), or open up the geometry (C4, C7). |

## Recommended rules

| Id | Rule | How the tool checks it | Message | Fix |
|---|---|---|---|---|
| R1 | Mesh names say what a mesh is (a category word or prefix), or the configuration maps names or materials to categories. | Every mesh goes through the category rules in order: the configuration's `category_rules`, then the default name vocabulary (below), then geometry (below). The report counts each way and lists the meshes geometry classified or left out. | `R1 WARN: <n> meshes matched no name rule and were classified by their shape (<counts>); <k> are in no category: <names>` | Names or `category_rules` (FIXED by geometry where it can). |
| R2 | Collision is given by collision nodes, Godot's naming convention: `<name>-col` (mesh plus trimesh collider), `-colonly` (trimesh collider, no mesh), `-convcol`, `-convcolonly` (convex). | Node names. When the model has any collision node, only those are used. Otherwise colliders come from the categories and shapes ("auto"): `ground` a trimesh per mesh; `buildings` per connected part its convex hull, or its own triangles (up to 20,000 per part) when the part is concave: its hull holds more than 1.3 times its volume (a closed part) or its upward faces cover less than 0.8 of the hull's footprint; `trees` and `lamps` an upright capsule round the trunk or post (the lowest tenth of the object; radius 0.15–1 m, up to 4 m high); `decor` per part a capsule for a pole (at most 0.6 m across, at least 1.5 m high), a box for a block (upward faces cover half its footprint) or a thin barrier (at most 0.6 m thick), its own triangles for anything else (a frame, an enclosure); parts smaller than 0.5 m, flatter than 2 cm, or lower than 0.3 m get none (the player steps over them); `facade_detail` and `water` none. `"colliders"` in the configuration changes this per category (`auto`, `trimesh`, `convex`, `box`, `capsule`, `none`). | `R2 INFO: no collision nodes; colliders generated from the categories: <counts>; <n> concave building parts … collide as their own triangles; <k> parts too small, flat, or low for a collider` | Collision nodes in the model, or `"colliders"`. |
| R3 | Separate objects: one mesh per building or block, not the whole city in one mesh; no non-ground mesh wider than 150 m. | A mesh no name rule matched that holds several separate objects is split into one mesh per object (step 0 of the geometry classification; FIXED). Horizontal extent of every non-ground mesh. | `R3 FIXED: <n> meshes no name rule matched held several separate objects and were split into one mesh per object: <name> (<parts>), …` / `R3 WARN: <n> non-ground meshes are wider than 150 m (<names>): visibility ranges and occlusion work per mesh, so they are drawn whole or not at all.` | Split the model into objects (a mesh whose name matched a rule is never split). |
| R4 | Every mesh has normals. | The glTF primitives' `NORMAL` attribute. | `R4 FIXED: <n> meshes had no normals; flat normals computed from the triangles` | Automatic: flat (per-face) normals. |
| R5 | Colour comes from textures or vertex colours. | Materials: a white, untextured material on a mesh with vertex colours does not show them in Godot. | `R5 FIXED: <n> materials show their vertex colours now` / `R5 WARN: <n> white untextured materials without vertex colours render white` | Automatic for vertex colours. |
| R6 | Materials are single-sided. | Materials whose cull mode is disabled (glTF `doubleSided`). | `R6 WARN: <n> double-sided materials: back faces are drawn too (fill-rate cost on mobile). Set "single_sided": true if the shells are closed (C7).` | `"single_sided": true` (FIXED). |
| R7 | Water is a separate mesh named `water` (or mapped by a rule). | Category counts. | `R7 INFO: <n> water meshes` | Name or rule. |
| R8 | The model holds only meshes. | Lights, cameras, skeletons, and animation players in the scene are left out (the map scene brings its own sun and sky). | `R8 FIXED: removed <n> lights, <m> cameras, …` (`R8 INFO` when there were none) | Automatic. |

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

For meshes no name rule matched, from the mesh's box in the map (after scale and axis fixes), its faces, how its vertices spread over its height, and how many meshes share its shape, in this order:

0. **Split first** (R3): a mesh of at most 50,000 triangles that holds several separate objects (at least 8 connected parts, spread over at least 4 times the largest part's footprint, at least 10 m wide both ways, three quarters of the parts standing on its lowest level) becomes one mesh per part (`<name>_000`, … with the same transform and materials) before the rules below. The pieces of one object (the beams of a timber frame at many heights, a fence's posts and rails along a line) are not split.
1. `ground`: wider than 20 m and at most a quarter as high as wide, or a flat tile (at least 2 m by 1 m, at most 0.3 m or 5 % of its width thick); in both cases at least half of what can be seen from above faces up (within 30° of +Y; a closed slab's underside does not count) and its walls are at most half of that.
2. `trees`: 1.5–40 m high, at most 25 m wide, a narrow trunk (the vertices of its lowest tenth span at most 0.35 of the crown's width) under a round crown (above 30 % of its height, at least 1 m across both ways and at least half as deep as wide).
3. `buildings`: at least 2.5 m high, at least 2 m wide both ways, at least a quarter of its area vertical (normals within 30° of horizontal), and either at least 3 m high or roofed (its upward faces cover at least half its footprint seen from above).
4. `decor`, an enclosure: at most 3.5 m high, at least half of its area vertical, covering under a fifth of its footprint from above (a fence or wall round a yard).
5. `decor`, a pole: at least 2 m high, its lowest tenth at most 0.6 m across, at most 3 m wide (lamp posts, signs, traffic lights; lamps are told apart only by name).
6. `decor`, a thin barrier: at most 0.6 m thick, 0.3–3.5 m high, at least 1.5 m long (fences, low walls).
7. `decor`, small or low: smaller than 2.5 m every way, or under 2.5 m high and at most 10 m wide (benches, planters, cars, kiosks), or up to 6 m and repeated at least 3 times (same triangle count and box to 1 cm).
8. `buildings`, a tall wall (over 3.5 m high, at most 2 m thick, at least 3 m long, half of its area vertical) or a tall slender block (at least 5 m high, under 2 m thick, three quarters of its area vertical: towers, columns, chimneys), which must not vanish beyond a visibility range like decor.
9. Otherwise no category (`default_category` in the configuration, empty by default).

Then a second look at the meshes classified so, that sit on a building (inside its box with 1 m around it): one made of many thin pieces (at least 4 parts, three quarters at most 0.4 m thick) within the building's height becomes `facade_detail` (windows, timber, frames); a cover (upward faces over half its footprint) above the building's lower half becomes `buildings` (its roof).

The tool stores this result in the map (each such mesh is in the Godot group `map_category_<category>`), and the map's category rules end with one rule per group, so the game sees the same categories the report shows. Measured accuracy: `PROJECT_STATE.md`, "Phase 6b".

## Placement (C8)

The tool places what gameplay needs with physics queries against the generated colliders:

| Item | Requirements | Choice among the candidates |
|---|---|---|
| Player spawn | The first hit of a ray down is a `ground` collider at most 20° steep; the player's capsule (radius 0.35 m, 1.8 m) fits there; no collider within 2 m between 0.5 and 2.0 m above the ground; at least 20 m of clear walk in the spawn's direction (1 m steps: ground under each step, a height change of at most 0.5 m per step, the capsule fits). | The candidate closest to the centre of the walkable area among those with the longest walks (capped at 40 m); it faces its longest walk. |
| Vehicle | A 7 m × 5 m area (the car plus room to get out on either side) with no collider between 0.3 and 2.5 m above the ground; ground under its corners and centre within 0.3 m in height and at most 8° steep; at least 25 m of clear road ahead (a 3 m wide box between 0.3 and 1.8 m above the ground every 2 m, ground under it, at most 0.6 m height change per 2 m); its centre at least 8 m from the spawn and 6 m from the spawn's walk. | The candidate with the longest drive (capped at 40 m), then the one closest to the spawn; it faces its drive. Placed 0.3 m above the ground. |
| NPC route | Two points 8–16 m apart (12 m tried first) on walkable ground, at least 10 m from the spawn, 6 m from the spawn's walk, and 4 m from the vehicle's drive; the capsule fits every 1 m along the path, with ground under it (height change at most 0.5 m per step). | The route closest to the spawn; the NPC waits 1.5 s at each point. |
| Viewpoints | Three walkable points (at most 20°) where the capsule fits, with a 2 m clear circle, at least 30 m from the spawn and from each other (fewer is a WARN), each facing the centre of the walkable area. | The points nearest that centre. |
| A sloped viewpoint | A vehicle place (as above, without the drive) on ground between 2° and 10° steep, for the device scenario's parked-on-a-slope steps. | Optional (INFO when none). |
| Bounds | The extent of the walkable samples, 1 m inside. | — |
| Kill height | 10 m below the lowest geometry, rounded down. | — |

Positions in the configuration (`"spawn"`, `"vehicle_spawn"`, `"npc_route"`) replace the search for that item.

## Configuration (optional JSON)

Every key is optional; the tool works without a configuration file.

| Key | Default | Meaning |
|---|---|---|
| `id` | from the file name | Registry id (`[a-z0-9_]`); the folder is `maps/<id>/`. |
| `display_name` | the id | Name in the debug overlay. |
| `scale` | 1, or a common unit the tool recognised (C2) | Uniform scale applied to the whole model (C2). |
| `up_axis` | detected (C3) | The file's direction that is up: `"y"`, `"-y"`, `"z"`, `"-z"`, `"x"`, `"-x"`; `"y"` keeps the file's axes. |
| `single_sided` | false | Back-face culling on every material (R6). |
| `category_rules` | [] | Ordered rules before the vocabulary: `{"category": "<category>", "prefix" \| "regex" \| "words" \| "material" \| "group": "<pattern>"}`; `prefix` is the start of the node name, `regex` searches the node name, `words` is a space-separated word list matched as in the vocabulary, `material` searches each surface's material name (regex), `group` a Godot group. |
| `category_rules_resource` | — | A `CategoryRules` resource (`.tres`) to use as the rules instead (the vocabulary and geometry still follow). |
| `use_default_name_rules` | true | The default vocabulary (R1). |
| `default_category` | `""` | Category for meshes nothing classifies. |
| `colliders` | ground trimesh, buildings, trees, lamps, decor `auto` | Collider type per category: `auto` (by shape, R2), `trimesh`, `convex`, `box`, `capsule`, `none`. With collision nodes in the model: `"colliders": "auto"` adds the category colliders to them. |
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

## Examples

Three maps were imported with the tool in Phase 6a (reports in `docs/maps/imported/`):

| Map | What it tested | Report |
|---|---|---|
| Kenney town (CC0, in the game) | Kenney's own scale (C2 FAIL with a suggestion, then FIXED by `"scale": 10`), names classified by the vocabulary, generated colliders | `kenney_town.md`, sources `kenney_town_source.md` |
| Safranbolu (the user's package, test input only) | no normals (R4 FIXED), no colliders (generated), open roofs and zero-area triangles (C7 WARN), roads inside buildings (avoided by the placement) | `safranbolu_test.md` |
| İstanbul • Haliç (the shipped GLB, test id) | collision nodes (827 `-col` bodies used, R2), a `CategoryRules` resource from the configuration, 7.07 M triangles (C6 WARN) | `istanbul_halic_import.md` |

Test imports whose sources are not in the repository go to `tests/imported/<id>/` (`--out=res://tests/imported/<id> --no-register`): ignored by Git and excluded from every export.

## Adding a map (user steps)

1. Put the GLB anywhere on disk (it is read, never copied or changed).
2. Optionally write a configuration JSON (above).
3. Run:

   ```bash
   godot --headless --path . --script res://tools/import_map.gd -- --glb=/path/to/map.glb [--config=/path/to/map.json] [--id=<id>]
   ```

4. Read the report (`docs/maps/imported/<id>.md`): every FAIL names the change to make; fix it in the model or the configuration and run the command again.
5. In a debug build, press MAP until the overlay names the map, or start with `--map=<id>`.
