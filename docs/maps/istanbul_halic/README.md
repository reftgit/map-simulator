# İstanbul • Haliç map — source and restore

The game's first map. It was produced outside this repository and copied in on 2026-10-24.

`<SOURCE_PACKAGE>` below stands for the folder on the maintainer's machine that holds the original `Istanbul_Halic` package (kept outside Git, in cloud storage).

## Origin

- Source package: `<SOURCE_PACKAGE>/Istanbul_Halic/` (not a Git repository). The original is never modified from this repository.
- The package's Godot project (`Godot/`) was copied to the repository root: `project.godot`, `main.tscn`, `scripts/`, `assets/`. All copied files matched the package's `manifest.sha256`. Godot 4.7.2's first import then added seven new default-valued keys to `assets/istanbul_halic.glb.import` before the first commit; no existing import value changed.
- Also copied: `ONCE_BUNU_OKU.md` (map documentation, Turkish) and `KAYNAKLAR.md` (data sources and attribution) into this folder, and `source/validate_scene.gd` as `tests/map/validate_scene.gd`.
- Not copied: `Istanbul_Halic.blend` (183 MB), `source/` generation scripts and OSM/DEM data, `previews/`, `CAMI_ENVANTERI.md`. They stay in the source package.

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

## Attribution

Geographic data © OpenStreetMap contributors (ODbL 1.0). Terrain: Mapzen/Tilezen Terrain Tiles (USGS, EU-DEM). Keep these attributions in any published build; details are in `KAYNAKLAR.md`.
