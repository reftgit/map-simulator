# İstanbul • Haliç map — source and restore

The game's first map. It was produced outside this repository and copied in on 2026-10-24. Since 2026-11-02 the game's default is the shader facade map built from the same generator (`istanbul_halic_cells_shader`, D25); İstanbul • Haliç is a selectable map. To run the game on a new machine, see "Running the game on a new machine" below.

`<SOURCE_PACKAGE>` below stands for the folder on the maintainer's machine that holds the original `Istanbul_Halic` package (kept outside Git, in cloud storage).

## Origin

- Source package: `<SOURCE_PACKAGE>/Istanbul_Halic/` (not a Git repository). The original is never modified from this repository.
- The package's Godot project (`Godot/`) was copied to the repository root: `project.godot`, `main.tscn`, `scripts/`, `assets/`. All copied files matched the package's `manifest.sha256`. Godot 4.7.2's first import then added seven new default-valued keys to `assets/istanbul_halic.glb.import` before the first commit; no existing import value changed.
- Also copied: `ONCE_BUNU_OKU.md` (map documentation, Turkish) and `KAYNAKLAR.md` (data sources and attribution) into this folder, and `source/validate_scene.gd` as `tests/map/validate_scene.gd`.
- Copied on 2026-11-01 from `Istanbul_Halic_Godot_Paketi.zip` (SHA-256 `726fb7ee00e8b6f6b0f10a82c34eb91ae542e9944feb9a3c6d745565f6e46a2c`, the same package with its `manifest.sha256`): the generation scripts, their inputs, and the records they wrote; see "Regenerating the map". The user produced the package and holds its rights (`PROJECT_CONTEXT.md`, D22).
- Not copied: `Istanbul_Halic.blend` (183 MB), `previews/`, `CAMI_ENVANTERI.md`, and the package's Godot demo (the copy at the repository root is the one used). They stay in the source package.

## The model file is not in Git

`assets/istanbul_halic.glb` is 502,541,456 bytes, above GitHub's 100 MB file limit, so it is listed in `.gitignore` (user decision, 2026-10-24). Every other project file is tracked, including `assets/istanbul_halic.glb.import`.

To restore it on a new clone or machine:

```bash
cp "<SOURCE_PACKAGE>/Istanbul_Halic/Godot/assets/istanbul_halic.glb" assets/
shasum -a 256 assets/istanbul_halic.glb
# expected: 8b00c94b240982488b755d85b78923b32158aaaeec716a576139bd55f21611b1
godot --headless --path . --import
```

The expected hash is the one recorded in the source package's `manifest.sha256`.

## Key facts for gameplay code

- 1 Godot unit = 1 metre. Axes: +X east, +Y up, -Z north.
- Size about 2.69 × 2.67 km; terrain elevation about 1.5–88 m.
- Walk spawn on the east sidewalk of the Galata Bridge: `(-109.0365, 6.5477, 204.2572)` (`assets/map_metadata.json` → `walk_spawn`). The floor below it is at y ≈ 4.55.
- Playable bounds (`map_metadata.json` → `bounds`, as east/north): x ∈ [-1931.65, 755.86], z ∈ [-1558.48, 1113.20].
- Static collision comes from `-col` nodes in the GLB (827 `StaticBody3D` nodes after import, collision layer 1). Small decor and water have no collision; anything that falls into the water drops below the map.
- About 7.07 million triangles, 3,055 mesh nodes, 9,001 buildings, 5,477 trees, 4,008 street lamps. Import generates LODs. The map was not built for mobile hardware.
- Every mesh carries flat per-face normals (`NORMAL`, unit length, the same on a triangle's three vertices) and vertex colours (`COLOR_0`); there are no textures. Checked on the shipped GLB (2026-11-01): 7,064,835 triangles' normals agree with their counter-clockwise winding, 113 disagree (fans over non-planar facade polygons), 5,509 have zero area.

## Regenerating the map

The generator is plain Python (no Blender, no network). It only reads its inputs and writes only to its output folder; it never replaces `assets/istanbul_halic.glb`. Decision and layout rationale: `PROJECT_CONTEXT.md`, T39; results of the reproduction: `PROJECT_STATE.md`, "Map generator in the repository".

| Path | Contents |
|---|---|
| `tools/maps/istanbul_halic/` | `build_map.py` (entry point) with its modules `terrain.py`, `architecture.py`, `bridge.py`, `vegetation.py`, `street_details.py`; `compare_outputs.py`; `blank_facades.py`; `render_map.py` (Blender previews, optional); `requirements.txt`, `.python-version` |
| `maps/istanbul_halic/source/` | Inputs, only read: `istanbul_extended_v4.osm` (OSM extract of 2026-09-26), `building_height_overrides.json`, `elevation/` (nine Terrarium tiles at zoom 14 and their `metadata.json`), `osm_v4_metadata.json` (the OSM API requests; documentation, not read by the scripts) |
| `maps/istanbul_halic/reference/` | What the package's run wrote for the shipped GLB (`statistics.json`, `buildings.json`, `spawn.json`, `mosques.json`, `bridge_metadata.json`, `vegetation.json`, `street_details.json`) and its validation records (`validation.json`, `vegetation_validation.json`, `godot_validation.txt`); for comparison, never written |
| `build/maps/istanbul_halic/` (default `--out`, ignored by Git) | `istanbul_halic.glb`, `map_metadata.json`, and the seven JSON records listed above |

Both `maps/` folders hold a `.gdignore`, so Godot neither imports the elevation PNGs nor packs the data into builds.

Setup, once (`<VENV>` is any folder outside the repository; Python 3.12):

```bash
python3.12 -m venv <VENV>
<VENV>/bin/python -m pip install -r tools/maps/istanbul_halic/requirements.txt
```

Generate and compare, from the repository root:

```bash
<VENV>/bin/python -B tools/maps/istanbul_halic/build_map.py            # options: --source DIR, --out DIR
<VENV>/bin/python -B tools/maps/istanbul_halic/compare_outputs.py      # vs assets/istanbul_halic.glb and reference/; --out DIR
```

`-B` keeps Python from writing `__pycache__/` beside the scripts (ignored by Git in any case). `--out` inside `--source` is refused. A run took 157 s on the Mac (Apple Silicon, 16 GB; two runs: 156.7 and 157.5 s) with a peak resident size of 3.4–3.6 GiB (peak memory footprint 4.7 GiB); `/usr/bin/time -l` in front of the command measures both. Two runs give byte-identical files.

Previews and the `.blend` (Blender 4.5; optional, not run in this repository so far):

```bash
blender --background --python tools/maps/istanbul_halic/render_map.py -- --out build/maps/istanbul_halic
```

A regenerated GLB is not byte-identical with the shipped one: the GEOS geometry library triangulates roads, pavements, and quays differently, a few traffic signal poles stand elsewhere, and the Atatürk bridge's seven piers stand 2.7–3.5 m away from where the shipped GLB has them (details in `PROJECT_STATE.md`). The game uses a regenerated map only as the separate cells map below (`PROJECT_CONTEXT.md`, D23).

### Cell grouping (`--detail-cell`)

`--detail-cell METRES` (more than 0, less than 150) gives facade detail (`Detail_*`), tree crowns (`Trees_*`), and shrubs (`Shrubs_*`) one mesh per cell of that size inside each 150 m chunk, named `<Category>_<cx>_<cy>_<i>_<j>`; each building, tree, or shrub goes whole into the cell of its centre, so no triangle changes. Everything else keeps its mesh: the other chunked categories, the per-landmark meshes (`MosqueDetail_<id>`, `LandmarkDetail_<id>` are already one mesh per mosque or landmark), and every `-col` mesh, including the tree trunks (`TreeTrunks_*-col` are collision bodies). Without the option the output is unchanged (`68237c46…`). `statistics.json` and `map_metadata.json` record `detail_cell_m` and the larger `mesh_nodes`.

```bash
<VENV>/bin/python -B tools/maps/istanbul_halic/build_map.py --detail-cell 40 --out build/maps/istanbul_halic_cells
<VENV>/bin/python -B tools/maps/istanbul_halic/compare_outputs.py --grouped --out build/maps/istanbul_halic_cells   # vs build/maps/istanbul_halic
```

`--grouped` compares with a run without the option (default `build/maps/istanbul_halic`, so generate that first) and passes (exit code 0) only when the header and every mesh outside the three categories are byte-identical, the cells of each chunk hold exactly the chunk's triangles (position, normal, and colour of every corner, as a multiset), and the triangle, vertex, and area totals per category match.

`<VENV>/bin/python -B tools/maps/istanbul_halic/blank_facades.py --cells 40 build/maps/istanbul_halic_cells` estimates, for 3,000 street points, the share of nearby buildings whose facade detail a visibility range hides (Godot measures the range to the centre of a mesh's bounding box), for the run without the option and each given cell run; the cell size was chosen with it (`PROJECT_STATE.md`, "Cell grouping and the cells map").

### The cells map (`istanbul_halic_cells`)

A second map in the registry (`maps/istanbul_halic_cells/`): the same spawn, bounds, viewpoints, vehicle spawn, NPC routes, and scene setup as İstanbul • Haliç, with the GLB built with `--detail-cell 40`. It is loaded only with `--map=istanbul_halic_cells`, an experiment's `"map"` key, or the debug MAP button (debug and Release Perf builds); it is not the default. Its GLB is generated on each machine and ignored by Git; its import settings (`assets/istanbul_halic_cells.glb.import`, the same values as the shipped GLB's) and its baked occluders (`maps/istanbul_halic_cells/istanbul_halic_cells_occluders.scn`) are committed. Until the GLB is generated and imported the map counts as unavailable: the MAP button skips it, `--map` falls back to the default with a warning, and its tests report SKIP.

On a clean machine, after the setup above:

```bash
<VENV>/bin/python -B tools/maps/istanbul_halic/build_map.py --detail-cell 40 --out build/maps/istanbul_halic_cells
shasum -a 256 build/maps/istanbul_halic_cells/istanbul_halic.glb
# expected: 7973071a3ee900b0af4023fad310c250707d21ebbeea8161b334be4134053c9d (505,589,800 bytes)
cp build/maps/istanbul_halic_cells/istanbul_halic.glb assets/istanbul_halic_cells.glb
godot --headless --path . --import
```

A run took 157.9 s on the Mac (Apple Silicon, 16 GB) with a peak resident size of 3.6 GiB (peak memory footprint 4.8 GiB), and two runs are byte-identical; the import takes about 12 s. `tests/integration/test_istanbul_halic_cells.gd` checks the hash. After any change to the map's collision, re-bake its occluders: `godot --headless --path . --script res://tools/bake_occluders.gd -- --map=res://maps/istanbul_halic_cells/istanbul_halic_cells.tres`.

### Facade variants (`--facade`)

`--facade full|light|shader` changes only the facade detail of ordinary buildings (`Detail_*`); `full` (the default) is the original geometry, so `--facade full` gives `68237c46…` without cells and `7973071a…` with `--detail-cell 40`. Mosques, the Galata Tower, every `-col` mesh, trees, and all other meshes stay byte-identical. Analysis of what the facade is made of: `docs/perf/facade/generator/facade_analysis.md`.

- `light`: each window keeps its light surround and its glass; the mullions and sills are dropped; windows whose point 1 m in front of the wall lies inside a building with a higher roof are dropped, with the cornices and string courses hidden along such walls; balcony railings are flat bars. About half the facade triangles (`PROJECT_CONTEXT.md`, T41).
- `shader`: each wall of 2.8 m or more gets one panel 3 cm in front of it instead of its cornice, string courses, and windows; `maps/istanbul_halic_cells_shader/facade_windows.gdshader` draws them from the panel's UV (metres along the wall and above its ground line), UV2 (column width, wall height), colour (the wall colour), and colour alpha (a per-wall seed). The panels use a seventh GLB material, `Istanbul_FacadeWindows`, which the map's script replaces with the shader. Roofs, doors, awnings, chimneys, and balconies (with flat railings) stay geometry (T42). Since 2026-11-01 the shader box-filters each element over the pixel's footprint instead of fading distant windows to an average colour (T43, `docs/perf/facade_v2/`); that change is in the shader file only, so the GLB is still `60b9f729…`.

```bash
<VENV>/bin/python -B tools/maps/istanbul_halic/build_map.py --detail-cell 40 --facade light --out build/maps/istanbul_halic_cells_light
<VENV>/bin/python -B tools/maps/istanbul_halic/build_map.py --detail-cell 40 --facade shader --out build/maps/istanbul_halic_cells_shader
<VENV>/bin/python -B tools/maps/istanbul_halic/compare_outputs.py --facade --out build/maps/istanbul_halic_cells_light   # vs build/maps/istanbul_halic_cells
```

`--facade` (in `compare_outputs.py`) compares with the full build with the same cells (default `build/maps/istanbul_halic_cells`) and passes only when every mesh outside `Detail_*` is byte-identical (attributes, indices, material), the `Detail_*` names are the same, and the reference materials are unchanged (an appended one is listed); it prints the `Detail_*` reduction.

| Variant (with `--detail-cell 40`) | GLB SHA-256 | GLB bytes | `Detail_*` triangles | Run (Mac) | Peak resident / footprint |
|---|---|---|---|---|---|
| full (the cells map) | `7973071a…` | 505,589,800 | 4,187,598 | 157.9 s | 3.6 / 4.8 GiB |
| light | `6531ca28b0ba8be0648615af23b3b625f3c9e9beec39693f163a65e42375355b` | 363,099,796 | 2,092,604 (−50.03 %) | 139.0 s | 3.0 / 3.8 GiB |
| shader | `60b9f7295be0ca536822126cbcf182de8f6db96de772314c5a80a39b31755303` | 254,569,692 | 324,120 (−92.26 %) | 122.8 s | 2.4 / 2.4 GiB |

Each is the GLB of an experimental map: `istanbul_halic_cells_light` and `istanbul_halic_cells_shader` (`maps/istanbul_halic_cells_light/`, `maps/istanbul_halic_cells_shader/`), with the cells map's data and its occluders, loaded only with `--map`, an experiment's `"map"` key, or the debug MAP button, and skipped (their tests SKIP) while the GLB is missing. To use them on a clean machine, after generating as above:

```bash
shasum -a 256 build/maps/istanbul_halic_cells_light/istanbul_halic.glb build/maps/istanbul_halic_cells_shader/istanbul_halic.glb   # expected: the table above
cp build/maps/istanbul_halic_cells_light/istanbul_halic.glb assets/istanbul_halic_cells_light.glb
cp build/maps/istanbul_halic_cells_shader/istanbul_halic.glb assets/istanbul_halic_cells_shader.glb
godot --headless --path . --import
```

Their tests check these hashes. A visual comparison of all four İstanbul maps is in `docs/perf/facade/`. The user chose the shader facade (`PROJECT_CONTEXT.md`, D25), and since 2026-11-02 `istanbul_halic_cells_shader` is the game's default map (first in the registry); the light facade stays an experimental map. Its distant windows and device results: `docs/perf/facade_v2/`; the default decision: `docs/perf/default_map/`.

## Running the game on a new machine

A clone carries no map GLB: `assets/istanbul_halic.glb` is copied in from the source package and the `istanbul_halic_cells*.glb` are generated (D6, D23). The default map is first in `game/world/maps.tres`; while its GLB is missing the game starts on the first available map with a warning (İstanbul • Haliç when its GLB is copied in, else the test district, which needs no file) in every kind of build, and with no map available it shows an error (`PROJECT_CONTEXT.md`, T44).

1. Godot 4.7.2 and, for the map, Python 3.12 (`python3.12 -m venv <VENV>`, `<VENV>/bin/python -m pip install -r tools/maps/istanbul_halic/requirements.txt`, once).
2. Generate the default map's GLB and copy it in:

   ```bash
   <VENV>/bin/python -B tools/maps/istanbul_halic/build_map.py --detail-cell 40 --facade shader --out build/maps/istanbul_halic_cells_shader
   shasum -a 256 build/maps/istanbul_halic_cells_shader/istanbul_halic.glb
   # expected: 60b9f7295be0ca536822126cbcf182de8f6db96de772314c5a80a39b31755303 (254,569,692 bytes)
   cp build/maps/istanbul_halic_cells_shader/istanbul_halic.glb assets/istanbul_halic_cells_shader.glb
   ```

   On the Mac (Apple Silicon, 16 GB) the run took 122.8 s with a peak resident size of 2.4 GiB (peak memory footprint 2.4 GiB). It needs no other generated file: the map's occluders (the cells map's, `maps/istanbul_halic_cells/istanbul_halic_cells_occluders.scn`) are committed.
3. `godot --headless --path . --import` (the shader GLB's import took 8.7 s on the Mac), then `godot --path .` starts on `istanbul_halic_cells_shader`; a debug build logs `STARTUP … map=istanbul_halic_cells_shader`.
4. Optional, for İstanbul • Haliç as a selectable map and its tests: copy its GLB as in "The model file is not in Git". The other generated maps: "The cells map" and "Facade variants" above.
5. Split the maps into a resident scene and streaming cells (`docs/STREAMING.md`; about 10 s for every map on the Mac), then import again:

   ```bash
   godot --headless --path . --script res://tools/cell_map.gd -- --all
   godot --headless --path . --import
   ```

   Without this step every map loads whole, as before (the definitions point at indexes that do not exist yet); with it the default map streams its facade detail, trees, lamps, and decor. Run it again after regenerating or copying in a GLB (a stale index is ignored with a warning).
6. `godot --headless --path . --script res://tests/run_tests.gd`: without a GLB the tests of its map report SKIP and the run exits 2.

A device build packs every map whose GLB is imported (five maps: Release Perf APK 675 MB), and their streaming files when they are written (about 740 MB more for the four İstanbul maps); a release package should carry only the default map's files (open question 36).

## Attribution

Geographic data © OpenStreetMap contributors (ODbL 1.0). Terrain: Mapzen/Tilezen Terrain Tiles (USGS, EU-DEM). Keep these attributions in any published build; details are in `KAYNAKLAR.md`.
