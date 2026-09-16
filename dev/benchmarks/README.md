# Writable-tag evaluation benchmarks

Compare the baseline public factory with the current factory on the same frozen workloads and both locked Nixpkgs revisions. The runner requires Python 3.12 or later, Nix, Git, GNU time at `/usr/bin/time`, and locally available development inputs. It does not download inputs or build packages during measurement.

Run from the repository root with no competing test evaluators or builds, choosing a new output directory:

```bash
python3 dev/benchmarks/run.py \
  --baseline 3fa01e7b5b92a707a857b9a85a13e8feae0dd89a \
  --pairs 7 --count 800 --output /tmp/cross-config-benchmark
```

The runner freezes the baseline and candidate factories in separate directories and copies one shared workload tree. Each workload and pin gets one warm-up per variant followed by seven measured pairs, alternating the order within each pair. Every sample starts a fresh offline evaluator with evaluation caching and import-from-derivation disabled. GNU time records wall time and peak resident memory; a separate process timer provides higher-resolution elapsed time in the raw results.

`writable-tags.nix` evaluates 800 independent two-node collections through the public factory. Each sender contributes an indexed string to a writable tagged submodule whose child permissions depend on the tag's original name. JSON evaluation forces each receiving value and both nodes' assertions.

`nixos.nix` uses the permanent NixOS integration fixture. An application conditionally contributes an upstream through a writable HTTP tag; the proxy consumes it in nginx alongside receiver-owned domain and firewall settings. The workload forces the tagged publication, nginx upstream, firewall ports, and both NixOS nodes' assertion booleans. It does not build a system closure.

Every output must match the baseline byte for byte within its pin and pass independent expected-value and assertion checks before the sample is accepted. `results.json` records raw samples, source hashes, runtime and machine details, pins, medians, ranges, ratios of medians, and paired changes. The output directory also contains both Markdown reports, individual outputs and timing files, and frozen source trees.

The accepted performance policy has no numerical gate. The small-collection stress cost does not predict full NixOS evaluation or deployment costs. See the committed [stress report](results/writable-tags.md), [NixOS report](results/nixos.md), and [raw measurements](results/results.json) for the final implementation results.
