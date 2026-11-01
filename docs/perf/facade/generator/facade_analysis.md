# Facade detail of the cells map by element (2026-11-01)

Counted with an instrumented copy of `build_map.py` outside the repository (each face of the
building loop tagged with its element; the copy stopped after the loop), `--detail-cell 40`,
pinned environment. The sum equals the cells map's `Detail_*` triangles.

| Element (`build_map.py`, building loop) | Triangles | Share of Detail_* |
|---|---|---|
| Window surround (light quad behind the glass; every window) | 1,080,318 | 25.8 % |
| Window glass (quad 2.5 cm in front of the surround; 88 % dark, 12 % light tint) | 1,080,318 | 25.8 % |
| Mullion (thin light quad; every other window) | 640,740 | 15.3 % |
| Sill (horizontal quad 0.2 m deep, seen from below; every other window) | 640,740 | 15.3 % |
| Balcony railing (6-sided bars: 2 posts, rail, balusters every 35 cm) | 264,264 | 6.3 % |
| String courses (band every 6.6 m of height, per wall) | 201,142 | 4.8 % |
| Cornice (band 12 cm out under the roof, per wall) | 82,442 | 2.0 % |
| Hip roof (slopes and top, 62 % of small convex buildings) | 43,988 | 1.1 % |
| Chimney (two boxes, every third building over 70 m²) | 42,060 | 1.0 % |
| Balcony slab (box) | 31,460 | 0.8 % |
| Awning (eight striped quads, 24 % of long front walls) | 24,656 | 0.6 % |
| Roof box (on flat roofs over 150 m²) | 20,170 | 0.5 % |
| Flat roof (triangulated footprint) | 18,014 | 0.4 % |
| Door (one quad per building) | 17,286 | 0.4 % |
| **Total** | **4,187,598** | **100 %** |

540,159 windows on 41,221 walls of 2.8 m or more (8,875 ordinary buildings; mosques and the
Galata Tower are in `MosqueDetail_*` / `LandmarkDetail_*` and not counted here).

Material and colour: every facade face uses the GLB's single vertex palette material
(`Istanbul_VertexPalette`, roughness 0.88, single-sided) with per-vertex `COLOR_0` (sRGB in the
generator, written linear) and a flat per-face normal; no textures or UVs. Colours: surround,
mullion, sill, cornice, string courses, balcony slab `LIGHT` E0D6BA; glass `DARK` 3A5057 or
80918E; railings `METAL` 526970; roofs from `ROOFS`, walls (in `Buildings_*-col`) from `PALETTE`.

Windows facing another building (the point in front of the wall inside a neighbour's footprint
whose roof is above the window's top):

| Distance in front of the wall | Hidden windows | Their triangles (share of Detail_*) |
|---|---|---|
| 0.3 m | 117,390 (21.7 %) | 743,540 (17.8 %) |
| 0.6 m | 121,593 (22.5 %) | 770,496 (18.4 %) |
| 1.0 m (used by `--facade light`) | 129,412 (24.0 %) | 820,404 (19.6 %) |
| 2.0 m | 146,955 (27.2 %) | 932,748 (22.3 %) |
