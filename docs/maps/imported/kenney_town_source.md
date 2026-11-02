# Kenney town: source and licence

The CC0 test map of Phase 6a (`PROJECT_CONTEXT.md`, D26): a 12 × 12 tile town composed from two Kenney asset packs and imported with `tools/import_map.gd` like any other map. Import report: `docs/maps/imported/kenney_town.md`.

## Licence

Both packs are released by Kenney (www.kenney.nl) under **Creative Commons Zero 1.0 Universal (CC0)**, as stated in each pack's `License.txt` ("You can use this content for personal, educational, and commercial purposes. Support by crediting 'Kenney' or 'www.kenney.nl' (this is not a requirement)") and on their download pages. The composed GLB is therefore CC0 as well. The licence text of the suburban pack is kept at `maps/kenney_town/source/License.txt` (the roads pack's is identical apart from its title and creation date).

## Sources (downloaded 2026-11-02)

| Pack | Version | Download | SHA-256 of the zip |
|---|---|---|---|
| City Kit (Suburban) | 2.0 (2025-04-23) | https://opengameart.org/content/city-kit-suburban → `kenney_city-kit-suburban_2.0.zip` (3,038,740 bytes) | `5869c35cf30b1c87bdb2d197b6d325eebadd2ef08ea27f04797e8e08d77a9a39` |
| City Kit (Roads) | 2.2 | https://opengameart.org/content/city-kit-roads → `kenney_city-kit-roads_2.2.zip` (2,852,289 bytes) | `374a4552115cbd11b4ec5c930ee31a533562dc78a09af249a655d03f7ea3b959` |

kenney.nl itself (https://kenney.nl/assets/city-kit-suburban, https://kenney.nl/assets/city-kit-roads) offers the same packs; its download button is a page script, so the OpenGameArt copies uploaded by Kenney were used. Only the packs' `Models/GLB format/` files were read; nothing of the packs except the composed GLB and the licence text is in the repository.

## Composition

`tools/maps/kenney_town/compose_town.gd` places the pieces on a fixed layout (no randomness; two runs gave the same SHA-256): roads along tile rows and columns 3 and 8 with crossroads where they meet (`road-straight`, `road-crossroad`), `tile-low` on every other tile, a street light (`light-square`) on every second road tile, the 21 house types (`building-type-a` … `-u`) in turn on every second lot beside a road, set back 0.15 tiles and facing it, a fence and a small tree on the other lots beside a road, and large trees inside the blocks. Every node keeps its Kenney piece name with its tile (`building-type-c_5_1`). The pieces keep Kenney's scale (a road tile is 1 unit), so the import needs `"scale": 10` (the tool's own suggestion, C2), which makes a road 10 m wide and a house 7–11 m high.

```bash
godot --headless --path . --script res://tools/maps/kenney_town/compose_town.gd -- \
    --suburban="<suburban pack>/Models/GLB format" --roads="<roads pack>/Models/GLB format" \
    --out=maps/kenney_town/source/kenney_town.glb
```

| File | Bytes | SHA-256 |
|---|---|---|
| `maps/kenney_town/source/kenney_town.glb` | 2,463,348 | `7de37a382dd9b6ef29fd100e874725126532783b0c2ae1552c7315f40785462d` |

269 nodes, 52,942 triangles, two materials (one texture atlas per pack), normals and UVs from the packs.

## Why it is in Git

The task allowed a CC0 test map under 10 MB in the repository. With the source GLB (2.5 MB), its configuration (`maps/kenney_town/source/kenney_town.json`), and the processed model (`maps/kenney_town/kenney_town_model.scn`, under 1 MB) committed, a fresh clone has one imported map that runs and is tested without any generated file, and the import can be repeated from the repository alone. `maps/kenney_town/source/` carries a `.gdignore`, so Godot neither imports the source GLB nor packs it into builds.
