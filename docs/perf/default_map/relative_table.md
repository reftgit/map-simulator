| Run | Experiment | Map | Long frames per viewpoint (Spawn / Karaköy street, facing north / Galata street, facing south) | Bad launch | Battery start → end °C | Cool-down wait s |
|---|---|---|---|---|---|---|
| run1 | c_relative_shader | istanbul_halic_cells_shader | 3 (0.2 %) / 3 (0.2 %) / 4 (0.2 %) | no | 31.5 → 32.5 | 0 |
| run1 | c_relative_istanbul | istanbul_halic | 3 (0.2 %) / 5 (0.3 %) / 6 (0.3 %) | no | 32.0 → 32.5 | 30 |
| run2 | c_relative_shader | istanbul_halic_cells_shader | 4 (0.2 %) / 4 (0.2 %) / 11 (0.6 %) | no | 32.0 → 33.0 | 90 |
| run2 | c_relative_istanbul | istanbul_halic | 72 (4.0 %) / 50 (2.8 %) / 130 (7.2 %) | **yes** | 32.0 → 33.5 | 60 |
| run3 | c_relative_shader | istanbul_halic_cells_shader | 1 (0.1 %) / 2 (0.1 %) / 6 (0.3 %) | no | 32.0 → 33.0 | 120 |
| run3 | c_relative_istanbul | istanbul_halic | 3 (0.2 %) / 2 (0.1 %) / 7 (0.4 %) | no | 32.0 → 33.0 | 150 |
| run4 | c_relative_shader | istanbul_halic_cells_shader | 2 (0.1 %) / 1 (0.1 %) / 3 (0.2 %) | no | 32.0 → 33.0 | 90 |
| run4 | c_relative_istanbul | istanbul_halic | 4 (0.2 %) / 3 (0.2 %) / 5 (0.3 %) | no | 32.0 → 33.0 | 120 |
| run5 | c_relative_shader | istanbul_halic_cells_shader | 4 (0.2 %) / 0 (0.0 %) / 6 (0.3 %) | no | 32.0 → 33.0 | 120 |
| run5 | c_relative_istanbul | istanbul_halic | 3 (0.2 %) / 3 (0.2 %) / 2 (0.1 %) | no | 32.0 → 33.0 | 150 |
| run6 | c_relative_shader | istanbul_halic_cells_shader | 5 (0.3 %) / 3 (0.2 %) / 3 (0.2 %) | no | 32.0 → 33.5 | 120 |
| run6 | c_relative_istanbul | istanbul_halic | 1 (0.1 %) / 0 (0.0 %) / 2 (0.1 %) | no | 32.0 → 32.5 | 120 |
| run7 | c_relative_shader | istanbul_halic_cells_shader | 46 (2.6 %) / 53 (2.9 %) / 105 (5.8 %) | **yes** | 32.0 → 33.5 | 90 |
| run7 | c_relative_istanbul | istanbul_halic | 4 (0.2 %) / 3 (0.2 %) / 0 (0.0 %) | no | 32.5 → 33.0 | 60 |
| run8 | c_relative_shader | istanbul_halic_cells_shader | 1 (0.1 %) / 0 (0.0 %) / 4 (0.2 %) | no | 32.0 → 33.0 | 90 |
| run8 | c_relative_istanbul | istanbul_halic | 4 (0.2 %) / 3 (0.2 %) / 6 (0.3 %) | no | 32.0 → 33.0 | 90 |
| run9 | c_relative_shader | istanbul_halic_cells_shader | 1 (0.1 %) / 1 (0.1 %) / 1 (0.1 %) | no | 32.0 → 33.0 | 90 |
| run9 | c_relative_istanbul | istanbul_halic | 4 (0.2 %) / 1 (0.1 %) / 5 (0.3 %) | no | 32.0 → 33.0 | 90 |

| Viewpoint | c_relative_shader: 1 % low median [launches] | c_relative_istanbul: 1 % low median [launches] | Difference | c_relative_shader: average FPS median (lowest) | c_relative_istanbul: average FPS median (lowest) |
|---|---|---|---|---|---|
| Spawn | 25.80 [25.83 / 25.64 / 25.75 / 25.80 / 26.18 / 25.42 / 23.66 / 25.80 / 26.24] | 25.77 [25.77 / 23.38 / 25.90 / 25.77 / 25.74 / 25.90 / 25.88 / 25.45 / 26.06] | +0.03 | 30.01 (30.00) | 30.01 (30.00) |
| Karaköy street, facing north | 25.89 [26.32 / 25.85 / 25.89 / 25.81 / 26.05 / 25.88 / 23.75 / 26.19 / 26.02] | 25.92 [25.71 / 23.50 / 26.12 / 25.78 / 26.11 / 26.14 / 25.92 / 25.83 / 26.23] | -0.03 | 30.01 (30.00) | 30.01 (30.00) |
| Galata street, facing south | 25.17 [25.23 / 24.64 / 25.17 / 25.13 / 25.20 / 25.09 / 22.68 / 25.26 / 25.20] | 24.98 [24.79 / 22.34 / 24.77 / 24.88 / 25.13 / 25.27 / 25.25 / 24.98 / 25.01] | +0.19 | 30.00 (29.99) | 30.01 (29.99) |

| Check | Result | Values |
|---|---|---|
| (a) at least 9 launches each | PASS | 9 and 9 |
| (b) bad launches at most one more than the reference's | PASS | 1 against 1 |
| (c) median 1 % low at most 0.5 FPS below the reference's at every viewpoint | PASS | +0.03, -0.03, +0.19 |
| (d) median average FPS at least 29.9 at every viewpoint | PASS | 30.01, 30.01, 30.00 |

Relative criterion: PASS
