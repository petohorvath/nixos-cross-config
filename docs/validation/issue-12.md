# Failure-check modernization validation

Issue [#12](https://github.com/petohorvath/nixos-cross-config/issues/12) moves the diagnostic and value-cycle checks to `nix eval`. The derivations declare `runCommand`, `nix`, `coreutils`, `gnugrep`, and the diagnostic runner's `lib` individually. The development flake supplies those dependencies through the stable package set's `callPackage`, while explicitly passing each fixture's own `nixpkgs` revision and `system`. The shared expression helper accepts `fixtureName`, and both runners bind its result as `expressionPath`.

Validation started from completed issue #11 at commit `9be1d4108333d83efa402aa6f12f9391459ab3e3` and ran on `x86_64-linux`. The host used Nix 2.34.6; the check derivations used their declared Nix 2.34.8 dependency. Stable remains locked to `c3eea5b2156db11c7eeeada3dc737711255b253e` and unstable to `ef34387ddd751e1ab8857adf4676492d32eb24ec`. Execution on `aarch64-linux` was not attempted.

## Evaluator behavior

Each invocation explicitly enables `nix-command` and uses `--offline --read-only --json --store dummy:// --file`. JSON evaluation forces nested values, preserving the former strict evaluation. Diagnostic invocations retain `--show-trace`; each cycle fixture retains its own evaluator process and must report `error: infinite recursion encountered`.

The first development build without `--read-only` failed because modern evaluation attempted `addToStoreFromDump`, which the dummy store cannot perform. The diagnostic fragment checks rejected that unrelated setup error. Adding the documented `--read-only` flag preserves evaluation without instantiating derivations in the isolated store. The successful builds below use the final commands.

Inspection of the generated expression files confirmed that all 33 diagnostic invocations and both cycle invocations per pin reference that pin's locked Nixpkgs source. The expected diagnostic reasons and applicable sender, receiver, destination, and original source-file fragments remain covered, including the additional tagged cases from #10.

## Complete checks

```bash
rtk nix build --offline --no-link --max-jobs 1 --print-build-logs \
  ./dev#checks.x86_64-linux.stable-diagnostics \
  ./dev#checks.x86_64-linux.unstable-diagnostics \
  ./dev#checks.x86_64-linux.stable-value-cycle \
  ./dev#checks.x86_64-linux.unstable-value-cycle \
  ./dev#checks.x86_64-linux.formatting
rtk git diff --check
```

Both commands exited 0. All five derivations built successfully without downloads. The cycle logs reported native recursion for both `value-cycle.nix` and `tagged-value-cycle.nix` on both pins.

| Pin | Diagnostic cases | Native cycles |
| --- | --- | --- |
| Stable | 33/33 | 2/2 |
| Unstable | 33/33 | 2/2 |

## Failure-guard probes

Temporary derivation overrides replaced one generated expression with a successful nested JSON value, or added an invalid CLI flag to the selected invocation. Each override also set `NIX_CONF_DIR` to a nonexistent directory and cleared experimental features through `NIX_CONFIG`. Successful evaluation and the first real cycle in the second-cycle probes therefore exercised the command's explicit feature enablement without host configuration.

The probe expression was saved outside the repository as `/tmp/nixos-cross-config-issue-12-probes.G1rasq/probe.nix`:

```nix
{
  repoDir,
  pin,
  kind,
  probe,
  fixtureIndex ? 0,
}:
let
  development = builtins.getFlake ("git+file://" + repoDir + "?dir=dev");
  inherit (development.inputs.stable) lib;
  check = development.checks.x86_64-linux."${pin}-${kind}";
  expressionPath = builtins.head (
    lib.splitString " " (
      builtins.elemAt (lib.splitString "--file " check.buildCommand) (fixtureIndex + 1)
    )
  );
  successfulPath = builtins.toFile "successful-fixture.nix" (
    if kind == "diagnostics" then
      "{ conflictingDestination = { nested = [ true ]; }; }"
    else
      "{ alpha = true; beta = [ false ]; }"
  );
in
check.overrideAttrs (old: {
  name = "issue-12-${pin}-${kind}-${probe}-${toString fixtureIndex}";
  NIX_CONF_DIR = "/no-nix-configuration";
  NIX_CONFIG = "experimental-features =";
  buildCommand =
    if probe == "success" then
      builtins.replaceStrings [ expressionPath ] [ successfulPath ] old.buildCommand
    else
      builtins.replaceStrings
        [ "--file ${expressionPath}" ]
        [ "--issue-12-invalid-option --file ${expressionPath}" ]
        old.buildCommand;
})
```

The temporary runner invoked this command for each row below, both `pin` values, and both `probe` values (`success` and `cli-error`):

```bash
rtk nix build --offline --no-link --max-jobs 1 --print-build-logs \
  --impure --option eval-cache false \
  --file /tmp/nixos-cross-config-issue-12-probes.G1rasq/probe.nix \
  --argstr repoDir /tmp/nixos-cross-config-11-13.JbuDt6/issue-12 \
  --argstr pin stable --argstr kind diagnostics \
  --argstr probe success --arg fixtureIndex 0
```

| `kind` | `fixtureIndex` | Selected fixture | Successful evaluation | Invalid CLI flag |
| --- | --- | --- | --- | --- |
| `diagnostics` | 0 | `conflictingDestination` | Rejected on both pins | Rejected on both pins |
| `value-cycle` | 0 | `value-cycle.nix` | Rejected on both pins | Rejected on both pins |
| `value-cycle` | 1 | `tagged-value-cycle.nix` | Rejected on both pins | Rejected on both pins |

All 12 builds failed with builder exit code 1 as required. Successful fixtures printed their JSON value and the applicable `Expected ... to fail` guard message. Invalid flags produced `unrecognised flag '--issue-12-invalid-option'`; diagnostic probes also reported missing diagnostic context. Cycle probes required the native recursion error from the selected process, so an unrelated CLI failure could not satisfy the check. The second-cycle probes first passed the real untagged cycle, then rejected the altered tagged fixture. The temporary runner verified these messages and exit codes and exited 0 with `12 probes passed`; its logs and JSON results are in `/tmp/nixos-cross-config-issue-12-probes.G1rasq/`.
