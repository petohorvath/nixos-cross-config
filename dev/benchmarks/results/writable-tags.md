# writable-tags evaluation benchmark

800 distinct two-node collections per evaluator process, each forwarding an indexed string into a writable tagged submodule with name-dependent permissions.

JSON evaluation forces every projected configuration value and both nodes' assertion booleans. Successful assertion messages remain lazy. Every warm-up and measured output matches the baseline byte for byte within its pin and passes independent value/assertion checks.

Measured at 2026-09-16T06:56:59.160906+00:00 using nix (Nix) 2.34.6, time (GNU Time) UNKNOWN, and Python 3.12.3. Machine: Linux-6.8.0-139-generic-x86_64-with-glibc2.39; 4 logical CPUs (AMD EPYC-Rome Processor); MemTotal:        7937220 kB. Evaluated system: `x86_64-linux`.

Baseline: `3fa01e7b5b92a707a857b9a85a13e8feae0dd89a`. Candidate production module SHA-256: `60df96a15ad969f7476aa4df3e34c3590c1fbabc0404ebffd35b28c51d9a3768`. Both factories are frozen in separate directories before measurement; identical workloads use resolved local Nixpkgs paths. The raw results record all source hashes and sample outputs' hashes.

This report records the repeat batch. Each variant and pin receives one warm-up followed by 7 measured pairs in alternating baseline/candidate order. Fresh evaluators run serially with evaluation caching and import-from-derivation disabled, offline, without builds or downloads. GNU time measures wall seconds and peak resident KiB; the raw data also retain a higher-resolution process wall timer. Memory below is MiB (KiB / 1024).

| Pin | Metric | Baseline median (range) | Candidate median (range) | Ratio of medians | Median paired change (range) |
| --- | --- | --- | --- | --- | --- |
| stable | Wall (s) | 1.460 (1.360–1.700) | 1.670 (1.540–1.810) | 1.144 | +16.31% (-5.29%–+23.13%) |
| stable | Peak RSS (MiB) | 418.398 (418.156–418.598) | 450.625 (450.387–450.727) | 1.077 | +7.72% (+7.63%–+7.76%) |
| unstable | Wall (s) | 1.390 (1.240–1.460) | 1.490 (1.410–1.610) | 1.072 | +11.81% (+2.80%–+15.79%) |
| unstable | Peak RSS (MiB) | 381.367 (381.055–381.555) | 435.477 (435.305–435.648) | 1.142 | +14.17% (+14.13%–+14.33%) |

## Reproduction

Run from the repository root with the locked inputs already available locally and no competing evaluator or build workloads. Choose a new output directory:

```bash
python3 dev/benchmarks/run.py --baseline 3fa01e7b5b92a707a857b9a85a13e8feae0dd89a --pairs 7 --count 800 --output /tmp/cross-config-benchmark
```

- stable: `c3eea5b2156db11c7eeeada3dc737711255b253e`, resolved locally as `/nix/store/zcqwwq108lzb92fggx0jaymdbb0b1lrb-source`.
- unstable: `ef34387ddd751e1ab8857adf4676492d32eb24ec`, resolved locally as `/nix/store/hhfnpma32czw4h3bqpag8dciax0bcmar-source`.

The runner writes both reports, raw measurements, timed commands' outputs, and frozen source/workload trees. There is no numerical performance gate; the stress cost of supported evaluation is accepted. These workloads measure evaluation only and do not predict deployment or full system-build costs.

## Repeat comparison

The first NixOS batch showed differences smaller than sample variation, so both workloads were measured again with the same sources, inputs, runner, sample count, and alternating order. Each batch includes one warm-up per variant and pin and seven measured pairs. Both raw batches are retained as [initial results](initial-results.json) and [repeat results](results.json); the table above reports the repeat batch.

| Pin | Initial wall ratio | Repeat wall ratio | Initial RSS ratio | Repeat RSS ratio |
| --- | --- | --- | --- | --- |
| stable | 1.155 | 1.144 | 1.077 | 1.077 |
| unstable | 1.114 | 1.072 | 1.142 | 1.142 |

Both batches show higher median wall time and peak memory for repeated writable-tag inspection. Across the two batches and pins, wall ratios range from 1.072 to 1.155 and memory ratios from 1.077 to 1.142. The magnitude varies with sample timing; this artificial workload amplifies the private evaluator cost and does not estimate full NixOS overhead.

Reproduce both batches with fresh output directories:

```bash
python3 dev/benchmarks/run.py --baseline 3fa01e7b5b92a707a857b9a85a13e8feae0dd89a --pairs 7 --count 800 --output /tmp/cross-config-initial
python3 dev/benchmarks/run.py --baseline 3fa01e7b5b92a707a857b9a85a13e8feae0dd89a --pairs 7 --count 800 --output /tmp/cross-config-repeat
```
