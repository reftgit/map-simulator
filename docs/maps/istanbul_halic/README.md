# İstanbul • Haliç map — source and restore

The game's first map. It was produced outside this repository and copied in on 2026-10-24.

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
| `tools/maps/istanbul_halic/` | `build_map.py` (entry point) with its modules `terrain.py`, `architecture.py`, `bridge.py`, `vegetation.py`, `street_details.py`; `compare_outputs.py`; `render_map.py` (Blender previews, optional); `requirements.txt`, `.python-version` |
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

A regenerated GLB is not byte-identical with the shipped one: the GEOS geometry library triangulates roads, pavements, and quays differently, and a few traffic signal poles stand elsewhere (details in `PROJECT_STATE.md`). Using a regenerated map in the game is a separate decision (`PROJECT_CONTEXT.md`, open question 39).

## Attribution

Geographic data © OpenStreetMap contributors (ODbL 1.0). Terrain: Mapzen/Tilezen Terrain Tiles (USGS, EU-DEM). Keep these attributions in any published build; details are in `KAYNAKLAR.md`.
