# Nix standards review findings

This record preserves the whole-codebase review against the writing-nix-code skill. All seven standards findings and one optional refactoring observation were unresolved at repository commit `3fa01e7b5b92a707a857b9a85a13e8feae0dd89a`. Issue #10 now resolves F1 with the supported evaluator composition, permanent regressions, and [validation and benchmark reports](../validation/issue-10.md). Issue #11 resolves F2 with factory source attribution and [public-factory validation](../validation/issue-11.md). Issue #12 resolves F3, F4, and F6 with modern failure-check commands, explicit dependencies, and [both-pin validation](../validation/issue-12.md). The other findings retain their separate issue scopes.

F1–F7 retain the original review numbering. J1 identifies the optional judgment call. These identifiers are review findings, separate from GitHub issue numbers. Existing [GitHub issue #1](https://github.com/petohorvath/nixos-cross-config/issues/1) concerns the original forwarding implementation and is closed.

## Findings

| ID | Finding and location | Follow-up | Status |
| --- | --- | --- | --- |
| F1 | Writable-tag destination inspection directly called `lib.modules.evalOptionValue` in [mk-module.nix](../../lib/mk-module.nix). Nixpkgs deprecates external use of this low-level evaluator. | Replaced by the supported `lib.evalModules` composition described in the [implementation brief](../specs/replace-deprecated-option-evaluation.md), preserving the interface, zero required inputs, read-only guard, and destination behavior on both pins. | Implemented for [#10](https://github.com/petohorvath/nixos-cross-config/issues/10); see [validation](../validation/issue-10.md). |
| F2 | The public factory used a plain import in [flake.nix](../../flake.nix#L5), rather than the skill's `importApply` convention for functions returning modules. | The receiver's `lib.setDefaultModuleLocation` attributes declarations to the imported module while retaining factory bindings, sender filenames, and zero required consumer inputs. | Implemented for [#11](https://github.com/petohorvath/nixos-cross-config/issues/11); see [validation](../validation/issue-11.md). |
| F3 | [Diagnostic checks](../../tests/check-diagnostics.nix) and [cycle checks](../../tests/check-value-cycle.nix) used legacy `nix-instantiate`. | Both runners now use `nix eval` with explicit command features, read-only offline evaluation, forced JSON results, and the existing diagnostic and native recursion guards. | Implemented for [#12](https://github.com/petohorvath/nixos-cross-config/issues/12); see [validation](../validation/issue-12.md). |
| F4 | The same [diagnostic](../../tests/check-diagnostics.nix#L1) and [cycle](../../tests/check-value-cycle.nix#L1) derivations accepted the whole `pkgs` set. | Individual top-level dependencies and `callPackage` callers retain stable build tools and each fixture's explicit Nixpkgs revision. | Implemented for [#12](https://github.com/petohorvath/nixos-cross-config/issues/12); see [validation](../validation/issue-12.md). |
| F5 | The main module result appears after roughly 230 lines of helpers in [mk-module.nix](../../lib/mk-module.nix#L252). | Arrange the code so callers precede their helpers and the module's intent is visible first. Preserve evaluation behavior. | Tracked in [#13](https://github.com/petohorvath/nixos-cross-config/issues/13). |
| F6 | The [diagnostic check](../../tests/check-diagnostics.nix) used `expression` for a file path; the shared helper's `fixture` argument held a filename. | [mk-failure-expression.nix](../../tests/mk-failure-expression.nix) and both callers now use `fixtureName` for filenames and `expressionPath` for generated paths. | Implemented for [#12](https://github.com/petohorvath/nixos-cross-config/issues/12); see [validation](../validation/issue-12.md). |
| F7 | [mk-module.nix](../../lib/mk-module.nix#L201) qualifies the already-global builtin as `builtins.removeAttrs`. | Use `removeAttrs` directly, following the skill's names-in-scope convention. | Tracked in [#13](https://github.com/petohorvath/nixos-cross-config/issues/13). |
| J1 | `findTypeOption` takes five curried arguments and `findMetadataOption` takes four in [mk-module.nix](../../lib/mk-module.nix#L140). | Consider named argument sets if they make recursive traversal easier to follow. This is a judgment call, not a required standards correction. | Deferred by the approved ticket breakdown; retained here. |

These are standards and maintainability findings. F1 addresses future compatibility with Nixpkgs; no current destination-validation failure has been established on either pin.

## Published follow-up tickets

1. **[Replace deprecated option evaluation, #10](https://github.com/petohorvath/nixos-cross-config/issues/10) (F1).** Use the finalized brief and [research note](../research/supported-option-evaluation.md). Add permanent regression coverage and report wall time and peak memory for both stress and representative NixOS workloads on both pins. The measured stress overhead is accepted; no automatic numerical gate applies.
2. **[Preserve factory module source attribution, #11](https://github.com/petohorvath/nixos-cross-config/issues/11) (F2).** Keep this change separate from the evaluator replacement and retain zero required consumer inputs.
3. **[Modernize failure checks, #12](https://github.com/petohorvath/nixos-cross-config/issues/12) (F3, F4, F6).** These findings affect the same test infrastructure and can be handled together with both-pin diagnostic and cycle validation.
4. **[Improve module reading order and builtin naming, #13](https://github.com/petohorvath/nixos-cross-config/issues/13) (F5, F7).** Keep this behavior-preserving cleanup separate from F1. Optional J1 is deferred from this ticket.

The approved breakdown was published on 2026-09-16 with all four issues labeled `ready-for-agent` and no blocking dependencies. GitHub remains the issue tracker; this document preserves the review evidence and maps findings to the work that resolves them. Consult the linked issues for current implementation status.

## Next flow

Issue #13 remains the final standards follow-up. Issue #12 modernizes the diagnostic and cycle infrastructure while retaining the writable-tag cases added by #10 and the factory source attribution from #11. Optional J1 remains deferred.
