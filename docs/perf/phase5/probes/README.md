# NPC cost probes on the Galaxy Tab A7 (Phase 5)

Single runs (not the three-run protocol) of "Android Release Perf" builds, low profile, 20 s warm-up and 40 s measurement per viewpoint, no PSS sampling. They decided the NPC design; the three-run results are in `../results/`.

| Folder | Build | Experiments | Finding |
|---|---|---|---|
| `probe/` | `a89274b` (NPCs always under the controller) | `c_npcs_on_low` (2 NPCs walking), `c_npcs_off_low` ("npcs": false) | +2.3–2.9 ms per physics step; 1 % low 24.4 / 24.6 / 23.6 vs 26.4 / 26.7 / 25.2. The second run waited out a 15-minute cool-down that ended at 30 °C (the first ran at 25.5–28 °C). |
| `probe2/` | working tree between `a89274b` and `eb7726f`: a far mode that moved the NPC with script every physics tick (not committed) | `c_npcs_far_low`, `c_npcs_off_low`, `c_npcs_full_low` ("npc_far_mode": false) | The scripted far walk still added 1.2–1.5 ms per step for the two NPCs; full controller +2.9–3.6 ms. The far run was the first launch after installing (most long frames). |
| `probe3/` | the Tween far mode as committed in `eb7726f` (built before the NPCs got names) | `c_npcs_full_low`, `c_npcs_far_low`, `c_npcs_off_low` | Far mode +0.04 / +0.55 / +0.26 ms per step, 1 % low 25.9 / 26.2 / 25.2 (off 26.3 / 26.7 / 25.9); full controller +2.5 / +2.9 / +2.7 ms, 1 % low 24.4 / 24.7 / 23.3. |

Viewpoints in that order: Spawn, Karaköy street, Galata street. Battery 31.5–34.5 °C in probes 2 and 3 (no cool-down waits).
