# nixos evaluation benchmark

One two-node NixOS collection per evaluator process: an application publishes a conditional upstream through a writable HTTP tag, and a proxy uses the result in nginx with a receiver-owned domain and firewall configuration.

JSON evaluation forces every projected configuration value and both nodes' assertion booleans. Successful assertion messages remain lazy. Every warm-up and measured output matches the baseline byte for byte within its pin and passes independent value/assertion checks.

Measured at 2026-09-16T06:56:59.160906+00:00 using nix (Nix) 2.34.6, time (GNU Time) UNKNOWN, and Python 3.12.3. Machine: Linux-6.8.0-139-generic-x86_64-with-glibc2.39; 4 logical CPUs (AMD EPYC-Rome Processor); MemTotal:        7937220 kB. Evaluated system: `x86_64-linux`.

Baseline: `3fa01e7b5b92a707a857b9a85a13e8feae0dd89a`. Candidate production module SHA-256: `60df96a15ad969f7476aa4df3e34c3590c1fbabc0404ebffd35b28c51d9a3768`. Both factories are frozen in separate directories before measurement; identical workloads use resolved local Nixpkgs paths. The raw results record all source hashes and sample outputs' hashes.

This report records the repeat batch. Each variant and pin receives one warm-up followed by 7 measured pairs in alternating baseline/candidate order. Fresh evaluators run serially with evaluation caching and import-from-derivation disabled, offline, without builds or downloads. GNU time measures wall seconds and peak resident KiB; the raw data also retain a higher-resolution process wall timer. Memory below is MiB (KiB / 1024).

| Pin | Metric | Baseline median (range) | Candidate median (range) | Ratio of medians | Median paired change (range) |
| --- | --- | --- | --- | --- | --- |
| stable | Wall (s) | 5.830 (5.610–6.060) | 5.780 (5.440–6.110) | 0.991 | +1.05% (-6.69%–+4.27%) |
| stable | Peak RSS (MiB) | 541.004 (540.969–541.148) | 541.082 (540.918–541.199) | 1.000 | +0.02% (-0.04%–+0.04%) |
| unstable | Wall (s) | 7.120 (6.920–7.900) | 6.980 (6.850–7.320) | 0.980 | -1.41% (-12.66%–+2.81%) |
| unstable | Peak RSS (MiB) | 656.160 (656.047–666.168) | 656.309 (656.141–693.859) | 1.000 | +0.03% (-1.51%–+5.75%) |

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
| stable | 0.984 | 0.991 | 1.000 | 1.000 |
| unstable | 1.007 | 0.980 | 1.000 | 1.000 |

NixOS wall-time differences remain within the observed spread after repetition. Ratios of medians range from 0.980 to 1.007 across the two batches and pins, while paired changes include both signs. These samples do not establish a speedup or a consistent slowdown for this fixture. Median peak memory remains within 0.03% of baseline; occasional larger peaks remain visible in the raw ranges, including the unstable candidate. No numerical acceptance gate is applied.

Reproduce both batches with fresh output directories:

```bash
python3 dev/benchmarks/run.py --baseline 3fa01e7b5b92a707a857b9a85a13e8feae0dd89a --pairs 7 --count 800 --output /tmp/cross-config-initial
python3 dev/benchmarks/run.py --baseline 3fa01e7b5b92a707a857b9a85a13e8feae0dd89a --pairs 7 --count 800 --output /tmp/cross-config-repeat
```
