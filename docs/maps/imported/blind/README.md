# Blind test of the import tool (Phase 6b): the unchanged tool on two unseen maps

Task of 2026-11-03: run the import tool of Phase 6a (`0aea505`), with no change to its code, vocabulary, thresholds, or configuration, on two maps it had never seen, and record the results as they came out; then one more run with the kind of configuration a user would write after reading the report. Fixes come afterwards and must be general (`PROJECT_STATE.md`, "Phase 6b").

## The two maps

| | Abstract city | Apollo 11 landing site |
|---|---|---|
| Author, licence | Keenan Crane (2011), public domain (CC0 on OpenGameArt) | NASA 3D Resources, "free and without copyright" |
| Source format | two Wavefront OBJ files (city, ground plane) with textures | one binary STL (3D-printing relief) |
| Converted with | `tools/convert_to_gltf.gd`, geometry as it is | same |
| How it differs from the Phase 6a maps | the whole city in **one mesh** (219 separate objects), **arbitrary units** (1.4 × 1.25 units), no object names, no normals | **Z-up**, **millimetres**, one closed mesh with a flat base, no colours, no normals |
| Sources and hashes | `docs/maps/imported/abstract_city_source.md` | `docs/maps/imported/apollo11_site_source.md` |

## Run 1: blind, no configuration

Commands: in the reports (`abstract_city_blind.md`, `apollo11_site_blind.md`); logs in `logs/`.

| Rule | Abstract city | Apollo 11 landing site |
|---|---|---|
| C1 | PASS (2 mesh nodes) | PASS (1 mesh node) |
| R4 | FIXED (flat normals on 2 meshes) | FIXED (1 mesh) |
| R5 | PASS (textures) | **WARN**: 1 white untextured material (the STL has no colour) |
| C2 | **FAIL**: 3.4 × 3.0 units is not a map; suggested `"scale": 20` ("typical object 9.5 m") | PASS: 256 × 19 × 256 m, "typical object 255.5 m" |
| C3 | PASS | **FAIL**: most flat area faces +Z, "looks Z-up", set `"up_axis": "z"` |
| C5, C6 | PASS | PASS |
| Result | not written | not written |

Raw views of the two files as they are: `shots/abstract_city_raw_blind.jpg`, `shots/apollo11_site_raw_blind.jpg` (the relief stands on its edge).

## Run 2: the configuration the report suggested

`abstract_city_config.json` = `{"scale": 20}`, `apollo11_site_config.json` = `{"up_axis": "z"}`; reports `abstract_city_config.md`, `apollo11_site_config.md`; output in `tests/imported/<id>_config/` (not in Git).

| | Abstract city | Apollo 11 landing site |
|---|---|---|
| Contract | C2 FIXED (68 × 61 m); R1 WARN: the city mesh classified by shape as one `buildings` mesh; C7 PASS | C3 FIXED; R1 PASS: the mesh name matched the vocabulary (`landing` starts with `land`, a ground word); C7 WARN 476 zero-area triangles |
| Categories | ground 1 (the ground plane, vocabulary `ground…`), buildings 1 (the whole city, shape) | ground 1 |
| Colliders | 215 convex hulls (one per connected part of the city), 4 parts skipped; the ground plane as trimesh | one trimesh, 142,768 triangles |
| Placement | walkable 95.9 %; spawn, car (8 m away), and NPC route on the bare ground plane beside the city; no sloped viewpoint | walkable 100 %; spawn near the centre, car 8 m away; no sloped viewpoint |
| Gameplay tests (`imported_map_case.gd`, 8) | 7 PASS: walk 39.1 m in 10 s, 5 s of throttle 44.3 m, punch and roll, NPC, map switch, device scenario; **1 FAIL**: `test_quality_profiles_apply` ("100 m on the 0 meshes with ranges") | 7 PASS: walk 44.5 m, throttle 44.3 m, …; **1 FAIL**: the same test |
| Shots | `shots/abstract_city_{spawn,vehicle,above,npc}_config.jpg` | `shots/apollo11_site_{spawn,vehicle,above,npc}_config.jpg` |

Test log: `logs/blind_config_tests.log` (the two test files were temporary and are not in the repository).

## What failed, and whose problem it is

| Finding | Kind | Detail |
|---|---|---|
| Abstract city: C2 FAIL | contract violation (the user must give the scale) | the file has no units; the tool cannot know them |
| Abstract city: the suggested scale 20 makes a toy city | **tool deficiency** | the suggestion scales the 90th-percentile *mesh* height to 8 m; with the whole city in one mesh that is the tallest tower, so the 219 towers become 0.3–5.6 m wide (median 0.9 m) and nobody fits between them (`shots/abstract_city_spawn_config.jpg`) |
| Abstract city: one category and no separation for 219 objects | **tool deficiency** | R3 only looks for meshes wider than 150 m; a mesh holding many separate objects is not detected, so every tower, block, and plinth is `buildings`, and no visibility range, occluder, or collider choice can work per object |
| Abstract city: no way into the city at any scale | property of the map | the towers' footprints nearly touch (median gap to the nearest neighbour 0.002 units against a median width of 0.04; 96 of 219 boxes overlap a neighbour): it is a skyline, not a street plan, so play happens on the ground plane around it |
| Apollo: C3 FAIL | contract violation, detected correctly | the tool named the exact fix; it could have applied it itself, the evidence being unambiguous (65,280 m² of faces toward +Z against 1,932 m² toward +Y) |
| Apollo: C2 measured before the axis | **tool deficiency** | "typical object 255.5 m" is the relief's width read as its height |
| Apollo: millimetres pass as metres | limit of any check | 255.5 mm read as 255.5 m is a plausible map size; nothing in the geometry tells the units |
| Apollo: the category came from the name by chance | weakness of the vocabulary | `landing` matched the ground word `land` |
| Both: `test_quality_profiles_apply` FAIL | **test assumption** | the shared test requires at least one mesh in a visibility-range category; maps without trees, lamps, decor, or facade detail have none, yet the profiles apply (FPS cap, baked occluders) |
| Both: no sloped viewpoint | map property | INFO; the device scenario skips its slope steps |

Classification at mesh level (the three meshes): the ground plane and the relief are ground (right), the city mesh is `buildings` as a whole, though it holds 219 objects of several kinds.

## After the general fixes (final state, Phase 6b commits 2–6)

The same two GLBs, imported with the fixed tool and a configuration a user would write (the abstract city: `{"scale": 100}`, the tool's own new suggestion, and a display name; the relief: only a display name). Reports with the blind runs side by side ("Compared with earlier imports"): `docs/maps/imported/abstract_city.md`, `docs/maps/imported/apollo11_site.md`; both maps are in the game (`maps/`, registry entries 9 and 10).

| | Abstract city: blind → suggested config → fixed | Apollo 11 landing site: blind → suggested config → fixed |
|---|---|---|
| Configuration | none → `{"scale": 20}` → `{"scale": 100}` | none → `{"up_axis": "z"}` → none (display name only) |
| C2 | FAIL (suggested 20) → FIXED → FIXED (now suggested 100: the typical object of 218 separate objects 28 m tall, 7 m wide) | PASS → PASS → PASS (millimetres not detectable) |
| C3 | PASS | FAIL → FIXED (configuration) → FIXED by the tool: "+Z up … its base is at the low end" |
| C7 | — → PASS → PASS | — → WARN (476 zero-area triangles) → FIXED (inside out: turned outward) + WARN (zero-area) |
| R3 | — → PASS → FIXED: the city mesh split into its 219 objects | PASS |
| Categories | — → buildings 1, ground 1 → buildings 203, decor 13, ground 1, none 3 | — → ground 1 → ground 1 |
| Colliders | — → 215 hulls → 187 hulls, 17 concave parts as trimesh, 13 boxes | trimesh |
| Placement | spawn, car, route on the bare plane beside a toy city → spawn in an alley at the city's edge, the car 15 m away beside the towers | spawn, car, route on the relief; now on its top surface, with a sloped viewpoint |
| Gameplay tests | 7 of 8 → 11 of 11 (8 shared + registry, split, extensibility scenario) | 7 of 8 → 10 of 10 (8 shared + registry, relief faces up) |
| Shots | `../shots/abstract_city_{spawn,vehicle,above,npc}.jpg` | `../shots/apollo11_site_{spawn,vehicle,above,npc}.jpg` |

### Classification accuracy (`labels/`)

- **Abstract city, hand-labelled sample:** 60 of its 219 objects drawn at random (seed 6) by `tools/map_import/sample_sheet.gd`, each shown in green among grey neighbours from above (`labels/abstract_city_sample_1–4.jpg`; six hidden ones again alone, `labels/abstract_city_isolated_1.jpg`), labelled by the agent before reading the tool's answers: 56 towers or blocks (`buildings`) and 4 low slabs (`decor`). The blind tool, which gave the whole mesh one category, had 56 of 60 right (it called the slabs buildings); the fixed tool 58 of 60 (two 4.8 m blocks in no category). `labels/abstract_city_labels.tsv` lists every sampled object with its label and both answers. The sample says little about trees, lamps, fences, or ground, which the city does not have.
- **Shape alone on the Phase 6a maps** (`"use_default_name_rules": false`, compared mesh by mesh with the name categories by `tools/map_import/compare_categories.gd`): Kenney town 249 of 269 (92.6 %; the 20 misses are lamps classified as decor, which lamps are not told apart from without names), Safranbolu 1,033 of 1,173 (88.1 %; 86 facade-detail meshes as buildings, 38 buildings and 5 others in no category): `labels/kenney_town_shape_only.tsv`, `labels/safranbolu_test_shape_only.tsv`. Before the fixes, the same runs crashed (the vocabulary switch had a bug since Phase 6a); by the old ground rule (wider than 20 m) none of the Kenney town's 10 m tiles is ground, so it would have failed C4.
- **The relief by shape alone:** ground (its name matched `land` by chance; with the vocabulary off the fixed rules still give ground, since a closed slab's underside no longer counts; the old rule gave nothing: 46 % of its area faces up, under the 50 % it required).
- Caveat: the low-object and slender-tower rules were written after seeing the city's unclassified objects, and the facade-detail and roof pass after seeing Safranbolu's shape-only result; none uses a name, but those two samples are not blind to the rules.
