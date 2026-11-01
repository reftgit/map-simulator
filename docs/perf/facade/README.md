# Facade variants: visual comparison (2026-11-01)

For the user's choice between the facade variants (`PROJECT_CONTEXT.md`, open question 42). Four maps from the same camera positions, with the high and the low quality profile:

| Column | Map | Facade detail |
|---|---|---|
| 1 | `istanbul_halic` | the shipped GLB, facade detail in 150 m chunks (the default map) |
| 2 | `istanbul_halic_cells` | the full facade in 40 m cells (T40) |
| 3 | `istanbul_halic_cells_light` | `--facade light` (T41): surrounds and glass, no mullions or sills, no windows facing a taller neighbour within 1 m, flat railings |
| 4 | `istanbul_halic_cells_shader` | `--facade shader` (T42): one panel per wall, windows, cornices, and string courses drawn by `facade_windows.gdshader` |

Rows: the spawn and the two measurement viewpoints (Karaköy, Galata), two near streets (Eminönü, Beyoğlu; dense buildings within 30 m), and a raised view over Karaköy (about 70 m up, 150–250 m from the buildings).

- `comparison_high.jpg`: all rows, high profile (200 m ranges, no fog).
- `comparison_low.jpg`: all rows, low profile (100 m ranges, fog, 0.6 render scale).
- `closeups_high.jpg`: 1:1 crops of the two near streets and the raised view, high profile, columns 2–4.

Captured on the Mac (Metal, Forward Mobile, 960×540, debug build) with `tools/capture_views.gd`, without the HUD; NPCs may stand elsewhere between the shots.

## Differences seen (high profile, against the full facade in cells)

**`cells_light`**
- Every window keeps its light surround and its glass with the same tint; the mullion in every other window is gone, so those windows read as one pane.
- No sills: under windows above eye level the light ledge seen from below is missing.
- Balcony railings are flat bars: the same from the front, without depth from the side.
- Windows on walls that face a taller neighbour within 1 m (24 % of all windows) and cornices and string courses hidden along such walls are gone; no shot shows such a wall, because it can only be seen from inside the gap.
- No new artefacts seen; from a distance (raised view) the same as the full facade.

**`cells_shader`**
- Windows, cornices, and string courses are painted on a flat panel 3 cm in front of the wall: no relief. The full facade's surround stands 2.5 cm out, the glass another 2.5 cm, the cornice 12 cm; at grazing angles (the near streets) the shader windows look flat and the cornice has no edge.
- The mullion is drawn; sills are not. The 12 % light glass falls on other windows than in the full facade (a hash instead of the generator's random sequence).
- Edges are box-filtered in the shader; no shimmering or aliasing beyond the geometry's own was seen in the still shots (moving shots were not compared).
- In the distance the window pattern fades to an average colour once a window is about two pixels wide: in the raised view the windows of the buildings 150–250 m away are fainter than in the full facade, and on small far buildings they disappear.
- No z-fighting between panel and wall was seen in any shot.
- Doors, awnings, roofs, roof boxes, chimneys, and balcony slabs are geometry as in the full facade.

**Low profile:** within the 100 m range the same differences, smaller on screen (0.6 render scale, fog); beyond it all four maps draw no facade detail. The `istanbul_halic` column still shows the blank nearby facades of the 150 m chunks at Galata, Karaköy, and the Beyoğlu street.

## Device evidence

- `shots/tablet_low_cells_light_shader.jpg`, `shots/iphone_high_cells_light_shader.jpg`: the benchmark frames of the cells, light, and shader maps at the three viewpoints on the Galaxy Tab A7 (low) and the iPhone 13 Pro (high), Release Perf builds.
- `results/`: the three-run results (`android/run1–3`, `pss`; `ios/run1–3`, `session`), the input of the tables in `PROJECT_STATE.md`, "Lighter facades on the cells map".
- `scenarios/`: the device scenarios on the shader map (results, tablet logs, the low-memory killer's lines).
- `generator/`: the facade analysis, the `compare_outputs.py --facade` outputs, hashes, and run times.
