# Apollo 11 landing site terrain: source, licence, conversion

One of the two maps of the Phase 6b blind test (`PROJECT_STATE.md`, "Phase 6b"): a terrain relief made for 3D printing, one closed mesh with a flat base, **Z-up** and in **millimetres** (255.5 × 255.5 × 18.7 units), no colours, no normals. Blind results: `docs/maps/imported/blind/`.

## Source and licence

| | |
|---|---|
| Work | "Apollo 11 - Landing Site", NASA 3D Resources (`3D Printing/Apollo 11 - Landing Site/`), exported from Blender 2.70 |
| Download | https://github.com/nasa/NASA-3D-Resources → `Apollo 11 - Landing Site.stl` (binary STL, 142,768 triangles), 7,138,484 bytes, SHA-256 `72eae5e493d3966dae392ce7563d66676e5a0b72d9753609d39723c8e84b1c72`, downloaded 2026-11-03 |
| Licence | The repository's README: "These assets are free and without copyright." NASA's media usage guidelines (https://www.nasa.gov/nasa-brand-center/images-and-media) ask that NASA's name and insignia are not used to suggest an endorsement; the map's name is therefore "Apollo 11 landing site", credited to NASA here |

## Conversion (STL is not glTF, C1)

Godot does not load STL, so the file was converted with the repository's converter, which writes the geometry as it is (no unit or axis change; `docs/MAP_CONTRACT.md`, "Supported formats"). The GLB therefore stays Z-up and in millimetres, as many simple converters leave it:

```bash
godot --headless --path . --script res://tools/convert_to_gltf.gd -- \
    --out=res://maps/apollo11_site/source/apollo11_site.glb "<dir>/Apollo 11 - Landing Site.stl"
```

One node, `Apollo 11 - Landing Site`, corners with equal positions welded, no material.

| File | Bytes | SHA-256 |
|---|---|---|
| `maps/apollo11_site/source/apollo11_site.glb` | 2,570,732 | `088254447b160634f9031f1f0e08561765d41ebf7ee9def3944ff8babe696fa2` |

`maps/apollo11_site/source/` carries a `.gdignore`, so Godot neither imports nor packs the GLB.

## Import

Configuration `maps/apollo11_site/source/apollo11_site.json`: `{"display_name": "Apollo 11 landing site"}` only; since Phase 6b the tool turns the relief to +Y up (C3) and its inside-out faces outward (C7) by itself. The millimetres stay metres (a 255.5 m map with 18.7 m of relief; C2 cannot see them). Report: `docs/maps/imported/apollo11_site.md`; blind results: `docs/maps/imported/blind/`. The processed model (3.4 MB) and occluders are committed in `maps/apollo11_site/`.
