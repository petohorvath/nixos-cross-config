# Destination inspection

Contributions define existing writable options on the receiver. The implementation in [lib/mk-module.nix](../lib/mk-module.nix) checks the receiver's declarations before merging contributions. An allowed option path may be absent or read-only on a node that receives no contributions at that path. An actual contribution to that destination fails with its sender, receiver, path, and source filenames. The [API reference](api.md#validation-and-errors) describes the resulting errors.

## Receiver-local declarations

The generated receiving configuration takes its outer namespace names from the receiver's declared options. Allowed-path filtering and contribution collection happen only when evaluation enters a namespace. This keeps the outer structure independent of the allowed-path list and received values, including for custom namespaces. Missing and read-only destinations still add no receiving definitions; assertions validate actual contributions separately.

The constructor continues to require the shared allowed-path list as a parameter, independently of received values, as described in [ADR 0004](adr/0004-declare-a-shared-forwarding-surface.md). The receiving structure does not reserve any namespace roots: existing writable destinations under `_module` or `crossConfig` remain eligible.

For a path inside a submodule, `findReceivingOption` uses `extendModules` to inspect the receiver while omitting contributions at that path. This lets receiver-local module functions, instance names, configuration, and freeform types determine whether the destination exists and is writable. These evaluations inspect destination metadata; they do not discover allowed paths or introduce a registration evaluation stage.

Traversal uses evaluated type metadata where available and retains native handling of wrappers such as `nullOr` and `unique`. A declaration-only walk through `getSubOptions` cannot establish instance-specific permissions. Root imports and declarations remain the caller's responsibility, as described in [ADR 0003](adr/0003-contribute-existing-option-definitions.md).

## Writable tags

An `attrTag` exposes tag declarations through `getSubOptions`. Missing tags stop traversal; read-only tags return their declaration without evaluating a writable payload. For a writable tag, `evaluateTagOption` declares that option in an isolated `lib.evalModules` evaluation and reads its metadata from `.options`.

The declaration uses the complete original option path. This preserves the name supplied to submodules and keeps a nested tag named `_module` beneath its parent. Each existing definition is supplied through `lib.mkDefinition`, retaining its filename, priority, ordering, and conditions. The declaration module's `_file` preserves the tag's original declaration location for defaults.

Inspection consumes the evaluated option's type and definitions while leaving its final `.value` and `apply` callback lazy. The receiver's type already closes over its submodule modules and special arguments. This composition uses the module evaluator without calling the deprecated external `evalOptionValue` interface or duplicating its default and definition handling.

## Laziness and diagnostics

Destination inspection must not force disabled contribution payloads or introduce dependencies on a tag's final merged value. Self-targeted and reciprocal contributions remain valid; actual value-dependency cycles retain native Nix recursion errors.

[Tagged-destination fixtures](../tests/tagged-destinations.nix) cover writable tags, names, wrappers, defaults, priorities, receiver-local permissions, and laziness. [Diagnostic checks](../tests/check-diagnostics.nix) verify contribution context and source locations; [cycle checks](../tests/check-value-cycle.nix) run separate evaluators because `tryEval` cannot catch native recursion errors. The [development guide](development.md#focused-checks) provides commands for both pinned revisions.
