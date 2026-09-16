# Writable-tag evaluator validation

Issue [#10](https://github.com/petohorvath/nixos-cross-config/issues/10) replaces the library's direct deprecated evaluator call with a private `lib.evalModules` composition. The selected writable tag retains its full option path, first declaration filename, and original definition filenames. Inspection reads `.options` and leaves the final value and `apply` lazy. Missing/read-only short circuits, the public factory, and the zero-input consumer flake remain intact.

The starting commit is `3fa01e7b5b92a707a857b9a85a13e8feae0dd89a`. Validation ran on `x86_64-linux` with Nix 2.34.6 against stable `c3eea5b2156db11c7eeeada3dc737711255b253e` and unstable `ef34387ddd751e1ab8857adf4676492d32eb24ec`. Both exported systems register the new fixtures and checks; execution on `aarch64-linux` was not attempted.

## Baseline and focused checks

The first writable-tag regression passed on both pins before changing the implementation. A frozen archive of the starting commit then supplied the public factory to the permanent fixtures. All 27 tagged cases matched the candidate on both pins. These include a NixOS application/proxy fixture, name-sensitive destinations, receiver-owned declarations and permissions, native wrappers, priorities, ordering, conditions, inactive registrations, and self/reciprocal contributions.

The laziness fixture evaluates forwarding assertions successfully and separately requires the final tagged value's throwing `apply` to fail. A temporary mutation removing preserved definition filenames loses the receiver's original source in the inspection diagnostic, demonstrating that the provenance regression detects the loss.

All 14 new expected diagnostic failures and both cycle fixtures were checked separately against the frozen baseline on both pins. Each diagnostic required its reason and applicable identity, destination, and source fragments. Each cycle required `error: infinite recursion encountered` from a separate evaluator.

Focused candidate commands:

```bash
nix eval --offline --option eval-cache false --json \
  ./dev#lib.tests.x86_64-linux.stable.taggedDestinations
nix eval --offline --option eval-cache false --json \
  ./dev#lib.tests.x86_64-linux.unstable.taggedDestinations
```

## Final checks

All 198 evaluation results passed: 99 per pin, including the 27 new tagged cases. The stable priority suite evaluated its nine cases together; other grouped cases ran individually. All fixture evaluations completed successfully, and the tagged groups were rerun against both factories after the review's test-ordering cleanup.

| Pin | Evaluation cases | Diagnostic cases | Native cycles |
| --- | --- | --- | --- |
| Stable | 99/99 | 33/33 | 2/2 |
| Unstable | 99/99 | 33/33 | 2/2 |

Both diagnostic derivations, both cycle derivations, and formatting passed:

```bash
nix build --offline --no-link \
  ./dev#checks.x86_64-linux.stable-diagnostics \
  ./dev#checks.x86_64-linux.unstable-diagnostics \
  ./dev#checks.x86_64-linux.stable-value-cycle \
  ./dev#checks.x86_64-linux.unstable-value-cycle \
  ./dev#checks.x86_64-linux.formatting
```

The cycle derivations each run the existing and tagged fixtures in independent evaluator processes. Diagnostic derivations retain the guard that rejects an unexpectedly successful evaluation. Their CLI and dependency conventions remain within the separately tracked modernization issue #12.

The complete evaluation suite runs each top-level fixture separately and expands grouped cases into individual processes. This preserves the existing assertions and native option typechecking while avoiding aggregate evaluator memory retention. Reproduce that coverage from the repository root:

```python
import json
import subprocess

command = ["nix", "eval", "--offline", "--option", "eval-cache", "false", "--json"]
for pin in ["stable", "unstable"]:
    prefix = f"./dev#lib.tests.x86_64-linux.{pin}"
    fixtures = json.loads(subprocess.check_output(command + [prefix, "--apply", "builtins.attrNames"]))
    for fixture in fixtures:
        paths = [f"{prefix}.{fixture}"]
        if fixture in ["destinations", "priorities", "taggedDestinations", "validation"]:
            names = json.loads(subprocess.check_output(command + [paths[0], "--apply", "builtins.attrNames"]))
            paths = [f"{paths[0]}.{name}" for name in names]
        for path in paths:
            assert json.loads(subprocess.check_output(command + [path])) is True, path
```

Python syntax validation also passed for the benchmark runner. Benchmark execution validates the runner's output comparisons and summary generation with real evaluations.

## Performance

The durable [benchmark runner and workloads](../../dev/benchmarks/README.md) compare identical baseline/candidate workloads using fixed local inputs and fresh serial processes. The [stress report](../../dev/benchmarks/results/writable-tags.md) and [NixOS report](../../dev/benchmarks/results/nixos.md) record the final measurements; [raw results](../../dev/benchmarks/results/results.json) retain every sample and source hash.

Two complete batches each ran one warm-up and seven alternating measured pairs per variant, pin, and workload. All 128 outputs matched their baseline and passed value/assertion checks. The second batch followed the first batch's inconclusive NixOS timing differences. Both raw batches are retained, and final source/workload hashes match both runs.

Across both batches, repeated small-collection inspection used 7–16% more median wall time and 8–14% more median peak memory. NixOS wall ratios ranged from 0.980 to 1.007 with overlapping sample variation and mixed paired changes, so the measurements establish neither a speedup nor a consistent slowdown for that fixture. Median NixOS memory changed by less than 0.03%; raw ranges retain occasional larger peaks. The accepted policy has no numerical performance gate.

Independent [standards and specification reviews](../reviews/issue-10-implementation.md) have no remaining findings.
