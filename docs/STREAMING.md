# Streaming

How a map's visibility-range meshes are loaded and freed around the camera, the same way for every map: the ones the import tool writes, the İstanbul generator's, and hand-made ones (D26). Decisions: `PROJECT_CONTEXT.md`, T54–T56; results: `PROJECT_STATE.md`, "Phase 6c".

## Why

On the Galaxy Tab A7 the app's memory follows the number of meshes, not their triangles: the default map keeps the cells map's 6,129 meshes and sits at 615 MiB stable PSS against İstanbul • Haliç's 502 MiB with 3,055 meshes, and the lighter facades cut 92 % of the facade triangles with the PSS barely moving. Most of those meshes are drawn only near the camera anyway: the quality profiles give the facade detail, trees, lamps, and decor a visibility range (100 m on the low profile, 200 m on the high one).

Measured on the Mac (Metal), default map loaded whole, then the 4,726 meshes of those four categories taken out of their nodes, then those nodes freed:

| State | Engine static memory | Video memory |
|---|---|---|
| Whole map | 233 MB | 308 MB |
| The 4,726 mesh resources dropped, nodes kept | 171 MB | 163 MB |
| The nodes freed too | 161 MB | 163 MB |

The meshes are what costs; their nodes cost about 2 KB each. So what streams is the mesh resource, and every node stays.

## The split (the cell step)

`tools/cell_map.gd` (library: `tools/map_import/map_cells.gd`; the import tool runs it after writing a map) reads only the map's `MapDefinition`: its scene and its category rules.

- **Streamed:** every mesh whose category (by the map's own `CategoryRules`) is one of `facade_detail`, `trees`, `lamps`, `decor`, the categories the profiles give a visibility range. A mesh that a resident node also uses stays resident with all its users.
- **Resident:** everything else: ground, buildings (landmarks are buildings), water, meshes in no category, every collider (a streamed mesh's `StaticBody3D` stays under its node), and the occluders (their own file, unchanged).
- **Cells:** a square grid on the ground plane (x, z of the map root), one cell per category and square, holding the meshes whose centre lies in it. The centre is the centre of the mesh's box in the map, the point Godot measures a visibility range to (3D distance from the camera; `RendererSceneCull`: `vd.position = transformed_aabb.get_center()`, `dist = camera_position.distance_to(vd.position)`). No mesh is cut.
- **Files** (`<map folder>/streaming/`; generated on each machine, ignored by Git, exported with the game when present):

| File | Contents |
|---|---|
| `<id>_resident.scn` | The whole map scene (its script, sky, sun, model) with the streamed meshes taken out of their nodes: every node, name, group, collider, and transform as in the map scene, so collision, occluders, categories, map scripts, and tests see the same map. |
| `cells/<category>_<i>_<j>.res` | A `MapCell`: the node paths and their meshes. |
| `materials/*.res` | Every material, a file of its own, so the resident scene and the cells use the same material object. |
| `meshes/*.res` | A mesh used in more than one cell (loaded once, freed with its last cell). |
| `<id>_index.tres` | The `MapStreamingIndex`: the resident scene, the cell size, per cell its file, category, square, the bounds of its meshes' centres, and its mesh, triangle, and byte counts; the materials to hold; the warm cells; the map's binary model files and their sizes. |

- **Link:** the cell step points the definition at its index (`MapDefinition.streaming_index_path`, a line added after `scene_path` in the `.tres`).
- **The default map:** split by the same step from its GLB scene (`assets/istanbul_halic_cells_shader.glb`, the shader facade map's script), not by its generator. One mechanism for every map (D26); the generator, its pinned output (`60b9f729…`), and the shader facade script stay as they are; the streaming grid does not depend on the generator's 40 m mesh cells or 150 m chunks.

## The loader

`WorldManager.load_map()` loads `index.resident_scene` instead of `scene_path` when the definition's index can be used (`MapStreamingIndex.load_for()`), and adds a `MapStreamer` (`game/world/map_streamer.gd`). `Main` gives it the camera as its focus and the effective visibility ranges after every profile change.

- **Radius per category:** its visibility range R from the effective settings (the profile with an experiment on top); none: infinite (every cell of it); hidden: none of it.
- **Wanted:** every cell whose meshes' centres lie within R + margin of the camera, and within R + margin of the point the camera reaches in `lookahead` seconds at its current velocity (a driving player). Cells are found on the grid around the camera, not by scanning every cell.
- **Loading:** missing wanted cells are queued nearest first and requested with `ResourceLoader.load_threaded_request`, at most `max_requests` at once; a loaded cell gets its meshes (`MeshInstance3D.mesh`) in the frame loop within `attach_budget_ms` of main-thread time per frame (at least one cell per frame), nearest first. A cell that arrives when it is no longer wanted is dropped.
- **Freeing:** a loaded cell beyond R + margin + hysteresis that is not wanted gives its nodes `null` meshes; the cell and its meshes are freed.
- **Warm cells:** the index names, for each material of the streamed meshes, the smallest cell using it; the streamer loads these when the map loads and never frees them (6 cells on the default map), so every material is in the scene from the start, as with the whole map. Without them the first cell bringing a material into the scene stalled the Galaxy Tab A7 for one frame of 100–109 ms and one of 77–79 ms, at the same spot of every route (the first traffic-signal glow), although attaching the cell took 0.2 ms; the whole map never stalled there. With them it was gone from the tablet's routes (the Mac and the iPhone never showed it).
- **Jumps:** the streamer processes after the camera (process priority 100). When the camera moved farther than the margin since the last frame (a teleport, respawn, vehicle reset, VIEW, CAR, the map's first frame), every wanted cell is loaded before that frame is drawn (`prime()`). `Main` primes once more after a map load and the profile, before the first frame or before the loading screen goes.
- **Primes load on the main thread.** Threaded requests made from `Main._ready()` at the app's start crashed a worker thread in 7 of 20 launches on the Mac (Metal; the same build loaded whole never crashed, and threaded requests made later from the frame loop never crashed in 40 launches); a prime is blocking anyway.
- **Renderers without a RenderingDevice** (the dummy renderer of headless runs, Compatibility) load cells on the main thread within the same budget: the dummy renderer creates mesh RIDs only on the main thread, and loading meshes on worker threads raced (errors when 2,612 cells loaded at once headless).
- **Map scripts:** a map script that sets meshes up at load (the İstanbul maps' vertex-colour albedo, the shader facade map's window shader) implements `prepare_streamed(instances)`, called for each cell's nodes after they got their meshes, and `prepare_streamed_materials(materials)`, called once at load with the streamed meshes' materials. The streamer holds those materials while the map is loaded, so a material set up once stays the same object when its cells load again. A material must be changed at load, not when its first cell arrives: on the Galaxy Tab A7 the İstanbul maps' vertex-colour flag set at first use made the renderer build a new shader in that frame (frames of 120–167 ms followed by 72–80 ms, right after an attach that itself took 0.2 ms).
- **Map switch:** `WorldManager.unload_map()` calls `MapStreamer.shutdown()`: requests in flight are waited for and dropped (Godot cannot cancel a threaded request, and an uncollected one keeps its resource), cells and materials are let go, and the streamer is freed with the map.
- **Pause and focus loss:** the streamer stops with the scene tree; requests in flight finish on their threads and are collected when it runs again.

| Tunable (`MapStreamer`) | Default | Meaning |
|---|---|---|
| `margin` | 30 m | loaded ahead beyond the range; also the largest camera move in one frame that does not prime |
| `hysteresis` | 30 m | further metres before a cell is freed |
| `lookahead` | 1.5 s | the camera's velocity looked ahead |
| `max_requests` | 1 | threaded requests in flight (four gave more 51–57 ms frames on the tablet's routes; one keeps up with a car at 15 m/s) |
| `attach_budget_ms` | 2 ms | main-thread time per frame for giving cells their meshes |

## Backward compatibility

A map loads whole, exactly as before, when its definition has no `streaming_index_path`, when the index or one of its files is missing (a fresh clone: the outputs are generated), or when the index is stale (one of the map's binary model files changed size since the split; a warning says to run the cell step again). The measurement key `"runtime": {"streaming": false}` loads any map whole; `"streaming_index"` uses another index (cell size comparisons).

## What it means for a map author

Nothing to do in the model: name or classify the detail meshes (facade detail, trees, lamps, decor), keep one object per mesh, and run `tools/cell_map.gd` (or the import tool, which runs it). A mesh is streamed whole, so a huge decor mesh is loaded whenever its centre is near; one object per mesh keeps the cells fine-grained (`docs/MAP_CONTRACT.md`, "Streaming").

## Cell size

50 m, the default of `tools/cell_map.gd` (`--cell-size` changes it). Two sizes were measured on the default map (the 100 m split written beside the first with `--out … --no-link` and chosen at runtime with `"streaming_index"`):

| | 50 m | 100 m |
|---|---|---|
| Cells, files | 2,612 cells, 67.2 MB | 1,254 cells, 66.7 MB |
| Tablet (Release Perf, low), stable PSS | 464 / 464 / 475 MiB (three runs) | 464 / 463 MiB (two runs) |
| Tablet, priming at the spawn | 6 cells, 68–100 ms | 5 cells, 81–106 ms |
| Mac, loaded at the three viewpoints, low (high) | 7 / 21 / 32 cells, 0.3–0.4 MB (38 / 56 / 95 cells, 0.8–1.4 MB) | 6 / 14 / 16 cells, 0.4–0.6 MB (25 / 32 / 41 cells, 0.9–1.6 MB) |
| Mac, driving route out and back (low): loads, longest attaching in a frame | 93 + 60, 0.27 ms | 49 + 31, 0.72 ms |

Memory is the same within the runs' spread: what dominates is not loading the 4,726 meshes at all, not the cell grain. 50 m holds less around the camera on the high profile, gives smaller attaching steps per frame, and keeps a cell a fraction of the low profile's 100 m range, at twice the files; it was kept.

## Tests

`tests/unit/test_map_cells.gd` (the split: cells by centre and category, the resident scene, shared materials and meshes, warm cells, nothing to stream, the link, unusable indexes, the import tool's categories), `tests/unit/test_map_streamer.gd` (range and margin, hysteresis, jumps, hidden and unranged categories, profile changes, the budget, lookahead, one request in flight by default, loads in flight and shutdown, dropped late loads, the map script's hook, pause), `tests/integration/test_map_streaming.gd` (in the game: the resident scene, walking and driving routes with no needed cell missing, the same meshes drawn with and without streaming, the route benchmark's streaming results, maps without an index, a map switch, teleport and respawn; the default map's three viewpoints on both profiles; the registry maps' cells up to date).
