# Abstract city: source, licence, conversion

One of the two maps of the Phase 6b blind test (`PROJECT_STATE.md`, "Phase 6b"): a whole city as one mesh, in arbitrary units (the city is 1.4 × 1.25 units), with no object names, no normals, and its ground plane in a separate file, by an author unrelated to the earlier test maps. Blind results: `docs/maps/imported/blind/`.

## Source and licence

| | |
|---|---|
| Work | "Chiba City Blues" (abstract city), Keenan Crane, 2011 |
| Download | https://opengameart.org/content/abstract-city (submitted by LFA, 2013; licence field: CC0) → `city.zip` (served as `city_0.zip`), 5,214,784 bytes, SHA-256 `58ea69ef4d3185a248008e5a6282e5dac48d4a66ef111279f34c3cda3b9d0b9b`, downloaded 2026-11-03 |
| Licence | Public domain: the archive's `README.txt` says "As the sole author of this data, I hereby release it into the public domain." (kept as `maps/abstract_city/source/README.txt`); OpenGameArt lists it as CC0 |
| Files used | `city/city.obj` (4,306 vertices, 3,702 polygons of 3–20 corners, texture coordinates, no normals, no objects or groups, no material library), `city/city.png` (2048², baked lighting), `city/groundplane.obj` (one quad), `city/groundplane.png` (1024²) |

## Conversion (OBJ is not glTF, C1)

Godot does not load OBJ at runtime, so the two OBJ files were converted with the repository's converter, which writes the geometry as it is (no unit or axis change; `docs/MAP_CONTRACT.md`, "Supported formats"):

```bash
godot --headless --path . --script res://tools/convert_to_gltf.gd -- \
    --out=res://maps/abstract_city/source/abstract_city.glb <dir>/city/city.obj <dir>/city/groundplane.obj
```

Each OBJ becomes one node named after its file (`city`, `groundplane`); as neither has a material library, each takes the PNG of its own name as its texture. Polygons are triangulated in their plane (7,742 triangles).

| File | Bytes | SHA-256 |
|---|---|---|
| `maps/abstract_city/source/abstract_city.glb` | 5,068,916 | `a0b82d3ec879cc2bceb19d42670792e125152fa13f196ee8bb0b65cc05b9977c` |

`maps/abstract_city/source/` carries a `.gdignore`, so Godot neither imports nor packs the GLB.
