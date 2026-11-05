# iPhone 13 Pro, Release Perf G, traced viewpoints

`python3 -I tools/perf/streaming_summary.py RESULTS.json` per run:

## run1

| file | view | map_ready_ms | frames | avg_fps | low1_fps | long_frames | over_50 | over_50_near_attach | over_50_near_request | over_50_near_free | max_ms | loads | unloads | attach_frames | attach_max_ms | missing_frames | loaded | draw_calls | primitives |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| c_streaming_shader_high.json | Spawn | 741 | 3601 | 60.0 | 57.93 | 0 | 0 | 0 | 0 | 0 | 18.3 | 0 | 0 | 0 | 0.0 | -1 | 44 | 261 | 182369 |
| c_streaming_shader_high.json | Karaköy street, facing north | 741 | 3601 | 60.01 | 55.97 | 0 | 0 | 0 | 0 | 0 | 19.6 | 0 | 0 | 0 | 0.0 | -1 | 62 | 167 | 111885 |
| c_streaming_shader_high.json | Galata street, facing south | 741 | 3601 | 60.01 | 53.59 | 0 | 0 | 0 | 0 | 0 | 20.0 | 0 | 0 | 0 | 0.0 | -1 | 103 | 90 | 58708 |
| c_streaming_shader_high_off.json | Spawn | 1275 | 3601 | 60.01 | 54.89 | 0 | 0 | 0 | 0 | 0 | 19.8 | - | - | - | - | - | - | 261 | 182361 |
| c_streaming_shader_high_off.json | Karaköy street, facing north | 1275 | 3601 | 60.01 | 55.56 | 0 | 0 | 0 | 0 | 0 | 20.1 | - | - | - | - | - | - | 167 | 111885 |
| c_streaming_shader_high_off.json | Galata street, facing south | 1275 | 3601 | 60.0 | 56.02 | 0 | 0 | 0 | 0 | 0 | 18.6 | - | - | - | - | - | - | 90 | 58708 |

## run2

| file | view | map_ready_ms | frames | avg_fps | low1_fps | long_frames | over_50 | over_50_near_attach | over_50_near_request | over_50_near_free | max_ms | loads | unloads | attach_frames | attach_max_ms | missing_frames | loaded | draw_calls | primitives |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| c_streaming_shader_high.json | Spawn | 749 | 3601 | 60.01 | 54.78 | 1 | 0 | 0 | 0 | 0 | 20.9 | 0 | 0 | 0 | 0.0 | -1 | 44 | 261 | 182369 |
| c_streaming_shader_high.json | Karaköy street, facing north | 749 | 3601 | 60.01 | 55.46 | 0 | 0 | 0 | 0 | 0 | 19.5 | 0 | 0 | 0 | 0.0 | -1 | 62 | 167 | 111885 |
| c_streaming_shader_high.json | Galata street, facing south | 749 | 3601 | 60.01 | 53.52 | 0 | 0 | 0 | 0 | 0 | 19.6 | 0 | 0 | 0 | 0.0 | -1 | 103 | 90 | 58708 |
| c_streaming_shader_high_off.json | Spawn | 1207 | 3601 | 60.0 | 58.09 | 0 | 0 | 0 | 0 | 0 | 18.1 | - | - | - | - | - | - | 261 | 182369 |
| c_streaming_shader_high_off.json | Karaköy street, facing north | 1207 | 3601 | 60.01 | 55.33 | 0 | 0 | 0 | 0 | 0 | 19.2 | - | - | - | - | - | - | 167 | 111885 |
| c_streaming_shader_high_off.json | Galata street, facing south | 1207 | 3601 | 60.01 | 53.32 | 0 | 0 | 0 | 0 | 0 | 20.8 | - | - | - | - | - | - | 90 | 58708 |

## run3

| file | view | map_ready_ms | frames | avg_fps | low1_fps | long_frames | over_50 | over_50_near_attach | over_50_near_request | over_50_near_free | max_ms | loads | unloads | attach_frames | attach_max_ms | missing_frames | loaded | draw_calls | primitives |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| c_streaming_shader_high.json | Spawn | 764 | 3601 | 60.0 | 57.78 | 0 | 0 | 0 | 0 | 0 | 20.4 | 0 | 0 | 0 | 0.0 | -1 | 44 | 261 | 182369 |
| c_streaming_shader_high.json | Karaköy street, facing north | 764 | 3601 | 60.01 | 55.09 | 1 | 0 | 0 | 0 | 0 | 21.5 | 0 | 0 | 0 | 0.0 | -1 | 62 | 167 | 111885 |
| c_streaming_shader_high.json | Galata street, facing south | 764 | 3601 | 60.0 | 53.44 | 0 | 0 | 0 | 0 | 0 | 19.5 | 0 | 0 | 0 | 0.0 | -1 | 103 | 90 | 58708 |
| c_streaming_shader_high_off.json | Spawn | 1211 | 3601 | 60.0 | 58.02 | 0 | 0 | 0 | 0 | 0 | 20.2 | - | - | - | - | - | - | 261 | 182369 |
| c_streaming_shader_high_off.json | Karaköy street, facing north | 1211 | 3601 | 60.01 | 55.29 | 0 | 0 | 0 | 0 | 0 | 19.7 | - | - | - | - | - | - | 167 | 111885 |
| c_streaming_shader_high_off.json | Galata street, facing south | 1211 | 3601 | 60.01 | 53.25 | 0 | 0 | 0 | 0 | 0 | 20.4 | - | - | - | - | - | - | 90 | 58708 |

## Every frame over 20 ms (`--timeline --over 20`), all six launches

| file | view | frame | t_s | ms | gpu_ms | render_cpu_ms | attach | request | free | pipelines |
|---|---|---|---|---|---|---|---|---|---|---|
| c_streaming_shader_high_off.json | Karaköy street, facing north | 2 | 0.04 | 20.1 | 0.0 | 2.9 | none | none | none | 0 |
| c_streaming_shader_high.json | Spawn | 3533 | 58.9 | 20.9 | 0.0 | 2.8 | none | none | none | 0 |
| c_streaming_shader_high_off.json | Galata street, facing south | 2 | 0.04 | 20.1 | 0.0 | 0.9 | none | none | none | 0 |
| c_streaming_shader_high_off.json | Galata street, facing south | 2086 | 34.77 | 20.8 | 0.0 | 1.6 | none | none | none | 0 |
| c_streaming_shader_high_off.json | Galata street, facing south | 3238 | 53.98 | 20.1 | 0.0 | 3.6 | none | none | none | 0 |
| c_streaming_shader_high.json | Spawn | 1430 | 23.85 | 20.4 | 0.0 | 2.6 | none | none | none | 0 |
| c_streaming_shader_high.json | Karaköy street, facing north | 2160 | 36.01 | 21.5 | 0.0 | 1.4 | none | none | none | 0 |
| c_streaming_shader_high_off.json | Spawn | 378 | 6.31 | 20.2 | 0.0 | 2.5 | none | none | none | 0 |
| c_streaming_shader_high_off.json | Galata street, facing south | 2 | 0.04 | 20.4 | 0.0 | 1.0 | none | none | none | 0 |

GPU times read 0.0 on iOS (Godot reports no GPU time with Metal here); the measurement windows had no cell attached, requested, or freed ("none").
