# Supported option evaluation for destination inspection

Use an isolated `lib.evalModules` evaluation to declare the selected `attrTag` option at its original path, supply its existing definitions with `lib.mkDefinition`, and read the resulting option from `.options`. This is a composition of documented module-system APIs. No separate, nondeprecated function with the full `evalOptionValue` interface was found in the inspected exports of either pin. [Public evaluator API](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/doc/module-system/module-system.chapter.md#L17-L69), [stable exports and deprecation](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/default.nix#L474-L515), [unstable exports and deprecation](https://github.com/NixOS/nixpkgs/blob/ef34387ddd751e1ab8857adf4676492d32eb24ec/lib/default.nix#L482-L523).

Research scope: repository commit `3fa01e7b5b92a707a857b9a85a13e8feae0dd89a`, using the revisions in [the development lock file](../../dev/flake.lock), on 2026-09-15. The research left production code, tests, and lock files unchanged. Issue #10 subsequently implemented the supported composition; [permanent public-factory regressions](../../tests/tagged-destinations.nix) and the [final validation record](../validation/issue-10.md) now provide durable evidence alongside the historical findings below.

## Baseline behavior

The deprecated call occurs only after destination inspection selects an existing, writable `attrTag` tag. Missing tags return `null`; read-only tags return their declaration before evaluation. The returned option feeds `findLocalOption`, which needs the tag's type and read-only metadata plus `highestPrio` and `definitionsWithLocations` for further traversal. It does not read the option's final `.value` or apply its `apply` callback. [Destination traversal](../../lib/mk-module.nix#L133-L178), [definition restoration](../../lib/mk-module.nix#L242-L250).

Receiver inspection uses an `extendModules` evaluation that omits the contribution at the path being inspected. Submodule traversal then uses the type's actual evaluated configuration, including receiver-local module functions, `name`, configuration-dependent declarations, and freeform types. Replacing that with a declaration-only walk would change the forwarding contract. [Local inspection and metadata traversal](../../lib/mk-module.nix#L97-L214), [receiver-owned declarations](../../docs/adr/0003-contribute-existing-option-definitions.md), [forwarding-surface contract](../../docs/adr/0004-declare-a-shared-forwarding-surface.md).

Nixpkgs itself still uses `evalOptionValue` inside `types.attrTag`. That internal use is intentional: the export is marked for `lib.types`, while external use is deprecated. Calling the supported `attrTag` or `evalModules` interface does not require avoiding their internal evaluator implementation. [Stable internal caller](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/types.nix#L979-L1005), [stable export annotation](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/modules.nix#L2296-L2297), [unstable internal caller](https://github.com/NixOS/nixpkgs/blob/ef34387ddd751e1ab8857adf4676492d32eb24ec/lib/types.nix#L1117-L1143).

## Candidate implementation

Replace only the call inside the writable-tag branch with a helper of this shape:

```nix
evaluateTagOption =
  {
    optionPath,
    tag,
    definitions,
  }:
  let
    evaluation = lib.evalModules {
      modules = [
        (
          lib.optionalAttrs (tag.declarations != [ ]) {
            _file = builtins.head tag.declarations;
          }
          // {
            options = lib.setAttrByPath optionPath tag;
            config = lib.setAttrByPath optionPath (
              lib.mkMerge (map lib.mkDefinition definitions)
            );
          }
        )
      ];
    };
  in
  lib.getAttrFromPath optionPath evaluation.options;
```

Pass `optionPath = prefix ++ [ segment ]`, `tag`, and `definitions = childDefinitions` from the existing branch. Preserve its missing/read-only short circuits and pass the result to the existing `findLocalOption`. Keep the helper private to this writable-tag inspection: grouping definitions in `mkMerge` is not a general replacement for the old evaluator's raw-definition count when enforcing `readOnly`. [Current guard and call site](../../lib/mk-module.nix#L159-L178), [read-only enforcement](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/modules.nix#L1138-L1154).

Use the complete original path. A synthetic option named `value` changes the location used to derive a submodule's `name`. Placing only the tag name at an evaluator's root can collide with its `_module` namespace. The documented `prefix` parameter can preserve locations, but the complete-path declaration also keeps a nested `_module` tag beneath its original parent. [Location and `name` contract](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/doc/module-system/module-system.chapter.md#L55-L57), [submodule evaluation](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/types.nix#L1339-L1357).

Preserve each definition's `file` and property wrappers by wrapping the whole `{ file; value; }` record with `mkDefinition`. Keep `mkForce`, `mkOrder`, and conditions inside its `value`. Set the declaration module's `_file` to the original first declaration filename so option defaults retain their source; leave it unset when the tag has no recorded declaration so the evaluator supplies its normal generated location. [Free-floating definitions](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/nixos/doc/manual/development/option-def.section.md#L146-L204), [default source handling](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/modules.nix#L1122-L1136).

Read `.options`, keeping `.config` and the option's `.value` lazy. The normal module evaluator remains responsible for defaults, definition normalization, ordering, and the optional `apply` function; destination inspection continues to consume the pre-`apply` definitions. The selected tag's type already retains its submodule modules and special arguments, so the helper does not need to copy the receiver's root module arguments. [Option evaluation](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/modules.nix#L1122-L1176), [submodule closure](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/types.nix#L1252-L1283).

## Compatibility and validation

| Property | Stable `c3eea5b2156d` | Unstable `ef34387ddd75` |
| --- | --- | --- |
| `evalModules`, `prefix`, and `.options` documented | Yes | Yes |
| External `evalOptionValue` deprecated | Yes | Yes |
| `attrTag.getSubOptions` returns tag declarations with locations | Yes | Yes |
| `attrTag` directly exposes nested configuration through `valueMeta` | No | No |

The two pins have equivalent relevant `attrTag` code. Their module evaluators and type wrappers differ elsewhere, including `nullOr` metadata, so compatibility must be checked against both pins. [Stable module-system documentation](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/doc/module-system/module-system.chapter.md), [unstable module-system documentation](https://github.com/NixOS/nixpkgs/blob/ef34387ddd751e1ab8857adf4676492d32eb24ec/doc/module-system/module-system.chapter.md), [stable types](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/types.nix#L979-L1119), [unstable types](https://github.com/NixOS/nixpkgs/blob/ef34387ddd751e1ab8857adf4676492d32eb24ec/lib/types.nix#L1117-L1289).

Existing tagged fixtures do not exercise the deprecated call: `unusedWrappedSubmoduleOption` asks for an absent tag and `readOnlyTaggedDestination` selects a directly read-only tag. Both return before line 177. Passing those fixtures alone would not establish replacement compatibility. [Existing wrapped destination case](../../tests/destinations.nix#L243-L299), [existing read-only tagged case](../../tests/destination-failures.nix#L3-L29).

The full-path candidate produced identical JSON to the unchanged implementation in 20 custom tagged-option integration cases on each pin: **40 baseline/candidate comparisons**. Results include configuration values, assertion booleans, and complete assertion messages with contribution provenance. The cases cover scalar and nested tags, `name`-dependent permissions, named `attrsOf` entries, receiver-local read-only metadata, missing children, disabled throwing payloads, receiver-local declarations, freeform fields, before/after ordering, forced definitions, outer forced definitions, unevaluated `apply`, empty declaration metadata without a default, `_module` and dotted tag names, and `coercedTo`/`either`/`nullOr`/`uniq` wrappers. [Temporary probe source](/tmp/nixos-cross-config-option-research.Ie4su7/tag-probes.nix), [stable result](/tmp/nixos-cross-config-option-research.Ie4su7/stable-candidate.json), [unstable result](/tmp/nixos-cross-config-option-research.Ie4su7/unstable-candidate.json).

Ten direct option-evaluation cases per pin also compared tag-level defaults, ordinary/`mkDefault`/`mkForce` definitions, ordering, eager and deliberately unevaluated `apply`, an undefined option, a submodule default, and empty declaration metadata. Values, priorities, source filenames, order markers, and definition availability agreed. A default-only option retained source `tag-origin.nix` and priority `1500`. In five cases per pin, the candidate retained an extra `_type = "definition"` marker on definition records. Applying the repository's `restoreDefinitionProperties` reconstruction discarded that marker and produced identical consumed results in **20/20 comparisons**. The candidate does not produce an identical generic option record. [Temporary direct probes](/tmp/nixos-cross-config-option-research.Ie4su7/option-probes.nix), [stable direct results](/tmp/nixos-cross-config-option-research.Ie4su7/stable-option-probes.json), [unstable direct results](/tmp/nixos-cross-config-option-research.Ie4su7/unstable-option-probes.json), [restoration code](../../lib/mk-module.nix#L242-L250).

Conditional self-contributions and reciprocal contributions through writable tags produced identical baseline/candidate results on both pins: **4/4 comparisons**. A tagged value-dependency cycle failed with `infinite recursion encountered` in all four separate evaluations: baseline and candidate on each pin. [Relationship probe source](/tmp/nixos-cross-config-option-research.Ie4su7/relationship-probes.nix), [stable relationship result](/tmp/nixos-cross-config-option-research.Ie4su7/stable-candidate-relationships.json), [unstable relationship result](/tmp/nixos-cross-config-option-research.Ie4su7/unstable-candidate-relationships.json).

The candidate also passed **58/58 existing NixOS fixture checks**: 12 positive destination cases and 17 expected failures on each pin. Failure checks required the expected reason and applicable sender, receiver, destination, and source-file fragments from the repository's diagnostic checks. These cases ran separately with `nix eval`, using the candidate as `crossConfig.lib.mkModule`; the complete development-flake test suite and build checks were not rerun. [Existing fixtures](../../tests/destinations.nix), [failure fixtures](../../tests/destination-failures.nix), [diagnostic expectations](../../tests/check-diagnostics.nix), [temporary result summary](/tmp/nixos-cross-config-option-research.Ie4su7/existing-fixture-results.json).

An additional `_type` tag case failed with an uncaught type error in both implementations and was excluded from the integration matrix. The trace differed; the comparison does not establish support for that tag or exact preservation of every internal stack trace.

The linked `/tmp/nixos-cross-config-option-research.Ie4su7/` sources, results, and logs are **ephemeral session evidence**, not committed test artifacts. This note preserves the original research findings. Permanent behavior, diagnostic, cycle, and performance coverage is linked from the [implementation validation record](../validation/issue-10.md); reproducing the implementation checks does not require those temporary files.

## Reproduction

Apply the candidate only to a copy of `lib/mk-module.nix`. The research harness imported the copied module as `crossConfig.lib.mkModule`, reused `tests/mk-nodes.nix`, and evaluated each destination case separately with `nix eval --json --impure --show-trace --expr`. The temporary [fixture harness](/tmp/nixos-cross-config-option-research.Ie4su7/public-tests.nix) and [runner](/tmp/nixos-cross-config-option-research.Ie4su7/run-existing.py) contain the exact invocations and diagnostic comparisons.

After implementing the replacement in an isolated checkout, the repository exposes the corresponding checks through these public commands; run individual destination attributes when evaluation memory is a concern:

```bash
nix eval --json ./dev#lib.tests.x86_64-linux.stable.destinations
nix eval --json ./dev#lib.tests.x86_64-linux.unstable.destinations
nix build --no-link \
  ./dev#checks.x86_64-linux.stable-diagnostics \
  ./dev#checks.x86_64-linux.unstable-diagnostics \
  ./dev#checks.x86_64-linux.stable-value-cycle \
  ./dev#checks.x86_64-linux.unstable-value-cycle
```

These build targets were not run during the original research. They subsequently passed during implementation validation. The [test runner](../../tests/default.nix) now registers permanent writable-tag cases; the original tagged cases alone bypassed the replaced branch. [Development-flake exports](../../dev/flake.nix).

## Alternatives

- **Call `lib.evalOptionValue` instead of `lib.modules.evalOptionValue`:** this uses the same implementation and triggers its explicit external-use deprecation. It does not resolve the finding. [Deprecation wrapper](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/default.nix#L515).
- **Replace it with `lib.mergeDefinitions` alone:** this exported, nondeprecated function merges definitions for a type, but does not construct an evaluated option or add the option's default. A specialized inspection adapter could add the default and reconstruct the two consumed definition fields; that would reproduce part of the low-level evaluator and depend on its less-documented result shape. Prefer the documented module evaluator. [Public export](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/default.nix#L474-L494), [merge implementation](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/modules.nix#L1204-L1261).
- **Use `getSubOptions` for every nested step:** that interface supports documentation discovery. It does not substitute for the receiver-local submodule evaluation used to discover instance-specific writable destinations. [Type interface](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/types.nix#L263-L270), [instance-dependent tests](../../tests/destinations.nix#L130-L240).
- **Read the merged tag value or rely only on `valueMeta`:** forcing the value introduces `apply` and value dependencies that this inspection does not need; `attrTag` currently uses the older merge interface without exposing nested configuration metadata. [Tag merge](https://github.com/NixOS/nixpkgs/blob/ef34387ddd751e1ab8857adf4676492d32eb24ec/lib/types.nix#L1121-L1145), [metadata fallback](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/modules.nix#L1288-L1326).

## Implementation acceptance criteria

1. Remove the repository's direct `evalOptionValue` call without changing `mkModule`, flake inputs, or the forwarding surface.
2. Add tests that actually traverse writable tags into nested submodules: valid destinations, missing fields, read-only fields controlled by `name` or receiver-local configuration, receiver-local option declarations, freeform fields, and nested wrappers. Include a tag named `_module` and an unevaluated `apply` callback during inspection.
3. Preserve default and definition filenames, override priorities, ordering, conditions, and free-floating definitions. Check diagnostics for the original sender, receiver, registered destination, and source filename.
4. Retain unused/disabled destination laziness and self/reciprocal contributions; actual value cycles must still fail with native recursion errors. Run the existing destination, merging, conditional, diagnostic, and recursion checks against both pinned revisions.
5. Review the additional evaluation cost and keep regenerated declaration metadata private. `evalModules` re-declares the selected option and normalizes its submodule type; the existing caller does not expose those declaration records. [Type normalization](https://github.com/NixOS/nixpkgs/blob/c3eea5b2156db11c7eeeada3dc737711255b253e/lib/modules.nix#L1487-L1499), [destination assertion](../../lib/mk-module.nix#L46-L59).

These criteria follow the repository's existing [forwarding behavior](../../README.md#sender-context-and-receiving-submodules), [cycle contract](../../docs/adr/0001-shared-evaluation-for-node-contributions.md), and [diagnostic assertions](../../tests/check-diagnostics.nix).
