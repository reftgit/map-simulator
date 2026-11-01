| Map hold | Stable PSS (MiB) |
|---|---|
| istanbul_halic_cells_shader (0–20 s) | 671 |
| istanbul_halic (30–50 s) | 585 |
| istanbul_halic_cells (61–81 s) | 693 |
| istanbul_halic (90–110 s) | 584 |
| istanbul_halic_cells_shader (118–138 s) | 673 |
| istanbul_halic_cells (148–168 s) | 696 |
| istanbul_halic_cells_shader (177–198 s) | 661 |

| Switch | Took (s) | Peak PSS (MiB) | Larger map stable + 50 | Result | Largest map stable + 50 | Result | Lowest PSS (old map freed) | Peak PSS + swap PSS |
|---|---|---|---|---|---|---|---|---|
| istanbul_halic_cells_shader -> istanbul_halic | 9.3 | 671 | 723 | PASS | 746 | PASS | 420 | 852 |
| istanbul_halic -> istanbul_halic_cells | 9.5 | 729 | 746 | PASS | 746 | PASS | 402 | 1024 |
| istanbul_halic_cells -> istanbul_halic | 7.8 | 692 | 746 | PASS | 746 | PASS | 406 | 951 |
| istanbul_halic -> istanbul_halic_cells_shader | 6.8 | 703 | 723 | PASS | 746 | PASS | 420 | 898 |
| istanbul_halic_cells_shader -> istanbul_halic_cells | 9.5 | 810 | 746 | FAIL | 746 | FAIL | 403 | 950 |
| istanbul_halic_cells -> istanbul_halic_cells_shader | 7.3 | 705 | 746 | PASS | 746 | PASS | 411 | 925 |

samples: 906, every 0.23 s on average; overall peak 810 MiB
