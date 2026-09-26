# Destination inspection

Contributions define existing writable options on the receiver. The [NixOS module](../nixos/module.nix) uses the private [destination inspector](../lib/destination-inspection.nix) to check the receiver's declarations before merging contributions. An allowed option path may be absent or read-only on a node that receives no contributions at that path. An actual contribution to that destination fails with its sender, receiver, path, and source filenames. The [API reference](api.md#validation-and-errors) describes the resulting errors.

## Receiver-local declarations

The generated receiving configuration takes its outer namespace names from the receiver's declared options. Allowed-path filtering and contribution collection happen only when evaluation enters a namespace. This keeps the outer structure independent of the allowed-path list and received values, including for custom namespaces. Missing and read-only destinations still add no receiving definitions; assertions validate actual contributions separately.

The shared allowed-path list comes from `crossConfig.optionPaths`. Normal option merging and priorities select registrations before normalization removes duplicate paths. The setup namespace `crossConfig` and module-system namespace `_module` stay outside generated receiving definitions, and registrations under those roots fail explicitly. These names remain valid inside ordinary receiving options. [ADR 0004](adr/0004-declare-a-shared-forwarding-surface.md) records why path registrations must remain independent of receiving configuration even though they are now module options.

The inspector receives the receiver's `lib`, declarations, `extendModules`, and active inspection paths, and returns a function from an option path to its declaration or `null`. It shares [definition-property restoration](../lib/restore-definition-properties.nix) with the sending module so both preserve priorities, ordering, and source locations.

For a path inside a submodule, `findReceivingOption` uses `extendModules` to inspect the receiver while omitting contributions at that path. This lets receiver-local module functions, instance names, configuration, and freeform types determine whether the destination exists and is writable. These evaluations inspect destination metadata; they do not discover allowed paths or introduce a registration evaluation stage.

Traversal uses evaluated type metadata where available and retains native handling of wrappers such as `nullOr` and `unique`. At each step, `evaluateOption` probes the current type with a stub definition naming the next path segment and reads the evaluated option's `valueMeta` and `definitionsWithLocations`. A declaration-only walk through `getSubOptions` cannot establish instance-specific permissions. Root imports and declarations remain the caller's responsibility, as described in [ADR 0003](adr/0003-contribute-existing-option-definitions.md).

## Writable tags

An `attrTag` exposes tag declarations through `getSubOptions`. Missing tags stop traversal; read-only tags return their declaration without evaluating a writable payload. For a writable tag, `evaluateOption` declares that option in an isolated `lib.evalModules` evaluation and reads its metadata from `.options`; type probes use the same evaluation.

The declaration uses the complete original option path. This preserves the name supplied to submodules and keeps a nested tag named `_module` beneath its parent. Each existing definition is supplied through its own module with the definition's filename as `_file`. Definitions arrive with overrides and conditions already discharged and keep their merge order. The declaration module's `_file` preserves the tag's original declaration location for defaults.

Inspection consumes the evaluated option's type and definitions while leaving its final `.value` and `apply` callback lazy. The receiver's type already closes over its submodule modules and special arguments. This composition uses the module evaluator without calling the deprecated external `evalOptionValue` interface or duplicating its default and definition handling.

## Laziness and diagnostics

Destination inspection must not force disabled contribution payloads or introduce dependencies on a tag's final merged value. Self-targeted and reciprocal contributions remain valid; actual value-dependency cycles retain native Nix recursion errors.

[Tagged-destination tests](../tests/suites/tagged-destinations.nix) cover writable tags, names, wrappers, defaults, priorities, receiver-local permissions, and laziness. Rejection cases declare their expected error type and message beside the expression, including contribution context and source locations. Reciprocal and tagged-destination suites also require native recursion errors for value-dependency cycles. nix-unit executes every assertion for a selected test; the [development guide](development.md#focused-checks) describes complete and focused runs.

## Module-system dependencies

Inspection reads nixpkgs module-system data that the NixOS manual does not fully document. Compatibility runs against the approved stable and unstable revisions exercise these dependencies; [ADR 0005](adr/0005-separate-nixpkgs-selection-from-compatibility-coverage.md) assigns that coverage to the shared policy.

- The evaluated option's `valueMeta` exposes submodule `configuration` and per-attribute `attrs` metadata. nixpkgs tests it but does not document it in the manual. If its shape changes, nested destinations are no longer inspected and missing or read-only destinations are accepted.
- The submodule `configuration` supplies `extendModules`, `options`, `config`, and `_module.freeformType` for receiver-local declarations and freeform types.
- `type.name` identifies the `nullOr`, `unique`, and `attrTag` wrappers; `type.nestedTypes.elemType` and `type.getSubOptions` expose their contents. The manual documents `name` and `getSubOptions` for custom types but not `nestedTypes`. A renamed wrapper would skip its native handling.
- `definitionsWithLocations` and `highestPrio` on evaluated options supply definitions for re-evaluation; nixpkgs helpers such as `mkDerivedConfig` also read them. The `priority` attribute on those definitions is an internal remnant of `mkOrder` sorting. [Definition-property restoration](../lib/restore-definition-properties.nix) relies on it; if it disappears, restored definitions lose their ordering.
