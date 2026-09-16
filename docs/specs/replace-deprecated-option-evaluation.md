# Replace deprecated option evaluation

Status: implemented for issue #10. See the [validation record](../validation/issue-10.md), [final stress benchmark](../../dev/benchmarks/results/writable-tags.md), and [final NixOS benchmark](../../dev/benchmarks/results/nixos.md).

Implementation ticket: [#10 — Replace deprecated evaluation in writable-tag destination checks](https://github.com/petohorvath/nixos-cross-config/issues/10).

Replace the direct `lib.modules.evalOptionValue` call in writable-tag destination inspection with the supported `lib.evalModules` composition validated in [the research note](../research/supported-option-evaluation.md). Finding F1 in the [review record](../reviews/nix-standards-review.md) is the scope of this change. The public factory and the forwarding behavior remain the compatibility boundary.

The library checks that a sender's contribution targets an existing writable option on the receiver. For destinations inside a writable tag, this check calls a low-level Nixpkgs helper intended for internal use. External use is deprecated on both tested revisions. Replacing this dependency reduces the risk that a Nixpkgs update breaks destination validation. No current behavior failure has been established on either pin.

Planning and implementation baseline: repository commit `3fa01e7b5b92a707a857b9a85a13e8feae0dd89a`. The requirements below preserve the agreed implementation scope.

## Fixed constraints

- Preserve `crossConfig.lib.mkModule { name; nodes; optionPaths; }` and the `crossConfig.nodes` declaration interface.
- Keep the consumer flake free of required inputs and use the `lib` supplied by the receiver's module evaluation.
- Preserve the existing missing-tag and read-only-tag short circuits before invoking the replacement helper.
- Keep the forwarding surface, caller-owned node collection, receiver-owned declarations, and receiver-local inspection evaluation intact.
- Preserve contribution values, override priorities, ordering, conditions, laziness, and error reasons with sender, receiver, registered destination, and source-file context.
- Preserve self-targeted and reciprocal contributions. Actual value-dependency cycles must still fail with Nix's native recursion error.
- Keep the existing lock file revisions: stable `c3eea5b2156db11c7eeeada3dc737711255b253e` and unstable `ef34387ddd751e1ab8857adf4676492d32eb24ec`.

These constraints follow the requested scope, [the public contract](../../README.md), and the existing [shared-computation](../adr/0001-shared-evaluation-for-node-contributions.md), [library boundary](../adr/0002-separate-forwarding-from-fleet-construction.md), [receiver declaration](../adr/0003-contribute-existing-option-definitions.md), and [forwarding surface](../adr/0004-declare-a-shared-forwarding-surface.md) decisions.

## Implementation

Keep a private helper in `lib/mk-module.nix` for inspecting one already-selected writable tag. Pass its original full option path, tag declaration, and collected child definitions in a named attribute set.

1. Declare the tag at its full original path inside `lib.evalModules`.
2. Pass each existing `{ file; value; }` definition through `lib.mkDefinition` and combine those definitions with `lib.mkMerge` at the same path.
3. Use the first recorded declaration filename as the declaration module's `_file` when one exists. Handle an empty declaration list without forcing `head`.
4. Retrieve the resulting declaration through `.options` and continue through the existing `findLocalOption` and `restoreDefinitionProperties` logic.
5. Leave the evaluated option's `.value` and `apply` callback lazy during inspection.

Retain the read-only short circuit: this helper is scoped to writable-tag inspection, and its grouped definitions are not a generic replacement for the old evaluator's raw-definition counting. Preserve the original path to retain submodule `name`, literal dotted segments, and a nested tag named `_module`.

The helper's regenerated declaration metadata and retained definition markers remain private. The compatibility assertions concern the fields actually consumed by inspection and the generated configuration; they do not require identical intermediate option records or native stack traces. The research note records these differences and the existing unsupported `_type` tag case.

Keep source-attribution finding #2, unrelated convention cleanup, new tagged-option support, and a reusable generic option evaluator outside this implementation scope.

## Permanent regression coverage

Use the public factory as the test boundary. Add focused tagged-destination integration fixtures in `tests/tagged-destinations.nix` and register them as `taggedDestinations` in `tests/default.nix`. Both locked revisions must execute the same cases. Keep cases individually addressable so evaluation can run in separate processes. Include a NixOS receiver with a writable tagged submodule for integration and performance validation.

| Behavior family                   | Required cases and observable assertions                                                                                                                                                                                                    |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Writable tags and location        | Scalar tag; nested submodule value; name-dependent writability; named `attrsOf` entry; literal dotted tag; tag named `_module`. Force resulting values and assertions.                                                                      |
| Receiver-owned structure          | Receiver-local option declaration; receiver-local freeform fields; read-only metadata controlled by receiver-local configuration. Preserve accepted values or reject the contribution with the expected reason.                             |
| Wrapped submodules                | Writable paths through `coercedTo`, `either`, `nullOr`, and `uniq`; retain the existing invalid-destination checks for those wrappers.                                                                                                      |
| Inactive and invalid destinations | Unused missing and read-only registrations; missing child under a writable tag; directly read-only tag; read-only child under a writable tag; disabled contribution with a throwing payload. Check that disabled values remain unevaluated. |
| Definition semantics              | Tag-level defaults; ordinary definitions; `mkDefault` and `mkForce`; ordering; outer transport selection; default and definition filenames; an empty declaration list without a default. Assert values and relevant diagnostic provenance.  |
| Inspection laziness               | An `apply` callback that throws if inspection forces it; receiver-local conditions and declarations remain usable. Force assertions separately from final values when testing this boundary.                                                |
| Node relationships                | A conditional self-contribution and reciprocal contributions through writable tags. Check each participating node's value and assertions.                                                                                                   |
| Failure diagnostics and cycles    | Tagged missing/read-only children, invalid values, and conflicts retain applicable reason and contribution context. A tagged value cycle fails in a separate evaluator with `infinite recursion encountered`.                               |

Extend the existing diagnostic and recursion-check infrastructure for expected failures. Run the existing value cycle and the new tagged cycle in separate evaluators on each pin so one failure cannot mask the other. `tryEval` is insufficient for the native recursion error. The current tagged fixtures return before the deprecated call, so merely rerunning them cannot establish coverage of the replacement.

Port the research probes into durable fixtures rather than depending on `/tmp` files. Preserve meaningful behavior checks and share fixture construction where useful; the number or layout of temporary probes is not a required test structure.

## Validation

Run the new cases against the existing implementation to establish their behavior, then against the replacement. The reference behavior must remain the native receiving-option semantics, not a second implementation of the new helper.

For both locked revisions, run the new tagged cases, all existing public evaluation fixtures, destination failure checks, diagnostic checks, and recursion checks. Run the project formatter and formatting check. Report each revision and command outcome. Use individually selected fixtures or equivalent separate-process coverage when a single evaluator retains too much memory; an interrupted or timed-out run is not a passing result.

The research established 58 existing destination-check passes, 64 targeted behavior comparisons, and four expected native cycle failures. Those results support the design; implementation validation must cover the final code and permanent tests.

After registering the new cases, the development flake provides these commands on the current host:

```bash
nix eval --json ./dev#lib.tests.x86_64-linux.stable.taggedDestinations
nix eval --json ./dev#lib.tests.x86_64-linux.unstable.taggedDestinations
nix build --no-link \
  ./dev#checks.x86_64-linux.stable-diagnostics \
  ./dev#checks.x86_64-linux.unstable-diagnostics \
  ./dev#checks.x86_64-linux.stable-value-cycle \
  ./dev#checks.x86_64-linux.unstable-value-cycle \
  ./dev#checks.x86_64-linux.formatting
```

These commands supplement the full existing public fixture coverage required above. Preserve registration for both systems already exported by the development flake; record which system was actually validated.

## Evaluation overhead

Compare the current implementation and candidate on identical workloads and both locked revisions. Keep implementation variants outside each other's source tree and evaluate them through the same public factory. Force identical configuration values and assertion results before accepting a timing sample.

Use fresh Nix processes with resolved local input paths, serial execution, and an explicit workload size. Run one warm-up per variant and pin, then at least seven measured pairs per pin, alternating baseline/candidate order. Avoid flake evaluation-cache hits, downloads, store builds, and unrelated test additions in the timed region.

Measure wall-clock evaluation time and peak resident memory with GNU `time`. Record the Nix version, machine, revision, pins, workload dimensions, sample count, median, range, and candidate-to-baseline change. Include a repeated writable-tag workload that actually reaches the changed branch and a representative public NixOS fixture workload. A tag-free fixture can serve as a control.

Keep the workload source and exact timing runner with the implementation's development tests so future measurements do not depend on this session's temporary files. Verify matching outputs before interpreting timings. Report both the ratio of medians and the median paired change; rerun measurements when the spread prevents a clear conclusion.

### Initial measurements

On 2026-09-16, Nix 2.34.6 on Linux x86_64 evaluated 800 distinct two-node collections per process. The KVM host exposed four AMD EPYC-Rome virtual CPUs. Each collection forwarded an indexed string into a writable tagged submodule whose read-only metadata depends on its name. The workload forced receiver values and both nodes' assertion booleans; successful assertion messages remained lazy. All outputs matched exactly between the frozen baseline and the research candidate on both pins.

One warm-up per variant and pin preceded seven alternating pairs per pin: 28 measured processes and four warm-ups. Python measured elapsed wall time around each process; GNU `time` recorded CPU time and peak resident memory. Inputs came from fixed local store paths, and `nix eval --json --impure --option eval-cache false --expr` started a fresh evaluator each time.

| Pin      | Baseline wall median (range) | Candidate wall median (range) | Median change | Baseline peak memory median | Candidate peak memory median | Memory change |
| -------- | ---------------------------- | ----------------------------- | ------------- | --------------------------- | ---------------------------- | ------------- |
| Stable   | 1.386 s (1.316–1.548)        | 1.702 s (1.625–1.820)         | +22.8%        | 414.57 MiB                  | 450.52 MiB                   | +8.7%         |
| Unstable | 1.276 s (1.243–1.334)        | 1.555 s (1.329–1.655)         | +21.9%        | 378.55 MiB                  | 431.96 MiB                   | +14.1%        |

Median paired wall-time changes were +20.8% stable and +20.1% unstable. The stress workload demonstrates measurable added cost; it does not predict full NixOS evaluation time. The existing NixOS tagged fixtures bypass the replaced call, so the new writable-tag NixOS fixture must supply the representative measurement during implementation.

The initial workload, runner, and raw results under `/tmp/nixos-cross-config-option-benchmark/` were ephemeral research evidence. The permanent [workloads and runner](../../dev/benchmarks/README.md) now reproduce the final implementation measurements independently of those files:

```bash
python3 dev/benchmarks/run.py \
  --baseline 3fa01e7b5b92a707a857b9a85a13e8feae0dd89a \
  --pairs 7 --count 800 --output /tmp/cross-config-benchmark
```

### Acceptance policy

The measured stress-workload cost is accepted in exchange for using the supported API. Reducing that overhead does not block implementation. There is no automatic numerical performance gate.

The required final baseline/candidate reports cover both the repeated writable-tag workload and the representative writable-tag NixOS fixture. Each report covers both locked revisions and includes wall time, peak resident memory, sample spread, output equivalence, and the reproduction procedure. The final stress measurements and NixOS measurements are linked in the status above; the initial research measurements do not replace them.

## Completion

The implementation is ready for review when the direct deprecated API call is gone, both pins satisfy the regression matrix, all required checks have completed, and both benchmark reports satisfy the agreed reporting policy. Review the diff against the implementation's recorded starting commit using this brief as the spec and writing-nix-code as the standards source.
