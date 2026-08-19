# Benchmark results

This file records a local run of the repository's deterministic application
benchmark CLI. The counters are emitted by the solver itself, so they are
useful for regression comparison without treating machine-dependent wall-clock
time as a correctness signal.

## Reproduction

```text
moon run --target native cmd/benchmark
```

Captured on 2026-08-19 on 64-bit Windows 11 (10.0.26200) with:

```text
moon 0.1.20260814 (a2de5b2 2026-08-14)
moonc v0.10.8+8606a5800 (2026-08-14)
moonrun 0.1.20260814 (a2de5b2 2026-08-14)
```

## Results

| Case | Solved | Solutions | Nodes | Propagations | Checks | Pruned | Depth |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| nqueens_8 | true | 1 | 325 | 649 | 18821 | 864 | 7 |
| sudoku_classic | true | 1 | 1 | 8 | 216 | 408 | 0 |
| latin_4 | true | 1 | 4 | 10 | 80 | 32 | 3 |
| grid_coloring_3x3 | true | 1 | 10 | 16 | 192 | 0 | 9 |
| schedule_4x4x2 | true | 1 | 6 | 11 | 165 | 12 | 5 |
| knapsack_4_items | true | 1 | 21 | 41 | 82 | 110 | 4 |

The suite's `benchmark_work` is `22084`, where work is
the sum of nodes, propagations, checks and pruned values across all cases.

## Raw CLI output

```text
nqueens_8: solved=true, solutions=1, nodes=325, propagations=649, checks=18821, pruned=864, depth=7, repeats=1
sudoku_classic: solved=true, solutions=1, nodes=1, propagations=8, checks=216, pruned=408, depth=0, repeats=1
latin_4: solved=true, solutions=1, nodes=4, propagations=10, checks=80, pruned=32, depth=3, repeats=1
grid_coloring_3x3: solved=true, solutions=1, nodes=10, propagations=16, checks=192, pruned=0, depth=9, repeats=1
schedule_4x4x2: solved=true, solutions=1, nodes=6, propagations=11, checks=165, pruned=12, depth=5, repeats=1
knapsack_4_items: solved=true, solutions=1, nodes=21, propagations=41, checks=82, pruned=110, depth=4, repeats=1
benchmark_work: 22084
```
