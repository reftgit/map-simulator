# Phase 6c tablet route traces re-read (2026-11-05)

The Galaxy Tab A7's route runs of Phase 6c (`docs/perf/phase6c/tablet/routes_D/`, `routes_E/`, `routes_F/`; battery draining in all of them), read with `python3 -I tools/perf/streaming_summary.py --timeline` (frames over 50 ms; those traces have no requests or frees: "-"). No new measurement.

| file | view | frame | t_s | ms | gpu_ms | render_cpu_ms | attach | request | free | pipelines |
|---|---|---|---|---|---|---|---|---|---|---|
| routes_F_c_route_drive_shader.json | Route out (vehicle) | 185 | 6.24 | 50.6 | 30.2 | 25.5 | -10 (1 cells, 0.25 ms) | - | - | 1 |
| routes_F_c_route_drive_shader.json | Route out (vehicle) | 400 | 13.43 | 52.0 | 36.6 | 5.3 | -3 (1 cells, 0.43 ms) | - | - | 0 |
| routes_F_c_route_drive_shader.json | Route out (vehicle) | 667 | 22.37 | 55.3 | 28.3 | 7.8 | -7 (1 cells, 0.47 ms) | - | - | 0 |
| routes_F_c_route_walk_shader.json | Route out | 596 | 19.95 | 52.1 | 29.1 | 5.4 | +5 (1 cells, 0.61 ms) | - | - | 1 |
| routes_E_c_route_walk_shader.json | Route out | 193 | 6.49 | 56.5 | 27.0 | 6.0 | +101 (1 cells, 0.42 ms) | - | - | 1 |
| routes_E_c_route_walk_shader.json | Route out | 601 | 20.14 | 51.3 | 29.5 | 11.3 | +2 (1 cells, 0.75 ms) | - | - | 0 |
| routes_E_c_route_walk_shader.json | Route out | 2940 | 98.12 | 50.2 | 28.2 | 12.5 | +0 (2 cells, 0.43 ms) | - | - | 0 |
| routes_E_c_route_walk_shader.json | Route back | 1780 | 59.39 | 50.9 | 31.1 | 14.4 | -12 (1 cells, 0.19 ms) | - | - | 0 |
| D_r1_c_route_drive_shader.json | Route out (vehicle) | 21 | 0.75 | 51.9 | 26.5 | 8.0 | -6 (1 cells, 0.20 ms) | - | - | 1 |
| D_r1_c_route_drive_shader.json | Route out (vehicle) | 75 | 2.62 | 105.0 | 25.8 | 7.8 | +0 (1 cells, 0.17 ms) | - | - | 0 |
| D_r1_c_route_drive_shader.json | Route out (vehicle) | 76 | 2.7 | 77.1 | 69.9 | 2.8 | -1 (1 cells, 0.17 ms) | - | - | 0 |
| D_r1_c_route_drive_shader.json | Route out (vehicle) | 402 | 13.6 | 55.5 | 31.9 | 4.7 | +3 (2 cells, 0.33 ms) | - | - | 0 |
| D_r1_c_route_walk_shader.json | Route out | 336 | 11.32 | 109.4 | 26.1 | 6.0 | +0 (1 cells, 0.21 ms) | - | - | 0 |
| D_r1_c_route_walk_shader.json | Route out | 337 | 11.4 | 79.3 | 71.4 | 3.1 | -1 (1 cells, 0.21 ms) | - | - | 0 |
| D_r2_c_route_drive_shader.json | Route out (vehicle) | 21 | 0.75 | 50.7 | 26.5 | 5.8 | -7 (1 cells, 0.27 ms) | - | - | 1 |
| D_r2_c_route_drive_shader.json | Route out (vehicle) | 78 | 2.72 | 105.3 | 25.6 | 11.5 | +0 (1 cells, 0.17 ms) | - | - | 0 |
| D_r2_c_route_drive_shader.json | Route out (vehicle) | 79 | 2.8 | 78.3 | 69.5 | 3.0 | -1 (1 cells, 0.17 ms) | - | - | 0 |
| D_r2_c_route_drive_shader.json | Route out (vehicle) | 231 | 7.91 | 56.2 | 30.5 | 12.5 | +4 (1 cells, 0.43 ms) | - | - | 0 |
| D_r2_c_route_drive_shader.json | Route out (vehicle) | 401 | 13.59 | 55.7 | 31.9 | 8.4 | +4 (2 cells, 0.40 ms) | - | - | 0 |
| D_r2_c_route_walk_shader.json | Route out | 336 | 11.32 | 100.2 | 26.2 | 8.7 | +0 (1 cells, 0.18 ms) | - | - | 0 |
| D_r2_c_route_walk_shader.json | Route out | 337 | 11.4 | 79.1 | 71.1 | 3.0 | -1 (1 cells, 0.18 ms) | - | - | 0 |
| D_r2_c_route_walk_shader.json | Route out | 594 | 19.99 | 52.1 | 29.4 | 5.4 | +3 (2 cells, 0.71 ms) | - | - | 1 |
| D_r2_c_route_walk_shader.json | Route out | 595 | 20.04 | 51.8 | 29.4 | 42.7 | +2 (2 cells, 0.71 ms) | - | - | 1 |
| D_r2_c_route_walk_shader.json | Route out | 597 | 20.12 | 51.9 | 29.6 | 10.2 | +0 (2 cells, 0.71 ms) | - | - | 0 |
| D_r2_c_route_walk_shader.json | Route out | 624 | 21.04 | 51.6 | 29.8 | 11.6 | +0 (3 cells, 0.55 ms) | - | - | 0 |
| D_r2_c_route_walk_shader.json | Route out | 2828 | 94.53 | 51.6 | 26.7 | 8.9 | -43 (1 cells, 0.23 ms) | - | - | 0 |
| D_r2_c_route_walk_shader.json | Route out | 3070 | 102.63 | 53.0 | 31.2 | 10.2 | -14 (1 cells, 0.35 ms) | - | - | 0 |
| D_r2_c_route_walk_shader.json | Route back | 270 | 9.06 | 56.7 | 31.3 | 7.5 | +0 (3 cells, 0.47 ms) | - | - | 0 |
| D_r2_c_route_walk_shader.json | Route back | 1651 | 55.12 | 51.9 | 30.0 | 9.7 | +0 (1 cells, 0.26 ms) | - | - | 0 |

File names: `routes_F_*` build F (the Phase 6c code), `routes_E_*` build E, `D_r1_*`, `D_r2_*` build D runs 1 and 2, `D_off1_*` build D with the map loaded whole (no frame over 50 ms; its longest frame in the walk out's 19–21.5 s window is 46.7 ms, GPU 29.2 ms). D's 100–109 ms frames at 2.6–2.8 s (drive) and 11.3 s (walk) are the first-material stall that the warm cells removed in E.
