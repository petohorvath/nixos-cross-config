# Module reading order validation

Issue [#13](https://github.com/petohorvath/nixos-cross-config/issues/13) places the returned module's declarations and configuration flow first in `lib/mk-module.nix`. Contribution, receiving-definition, and assertion builders follow in their call order. Shared helpers appear after their callers where the recursive inspection functions permit; `findDeclaration` follows both of its callers. The freeform inspection branch uses the global `removeAttrs` with its original arguments and no new lexical binding. Existing helper arguments remain unchanged, preserving the deferred J1 decision.

Validation started from completed issue #12 at commit `3925b019351bf473b1615b2ae461de187a707ae8` and ran on `x86_64-linux` with Nix 2.34.6. Stable remains locked to `c3eea5b2156db11c7eeeada3dc737711255b253e` and unstable to `ef34387ddd751e1ab8857adf4676492d32eb24ec`. Execution on `aarch64-linux` was not attempted.

## Public evaluation fixtures

The complete existing public suite runs each top-level fixture in a separate evaluator process and expands grouped fixtures into individual cases. This avoids the aggregate evaluator's memory retention while retaining the suite's assertions and native option typechecking. Coverage includes #10's 27 writable-tag cases and #11's factory source-attribution regression, along with definition priorities, ordering, conditions, sender context, self and reciprocal contributions, node identities, destination checks, and the zero-input consumer.

Run this Python program from the repository root with `rtk python3`:

```python
import json
import subprocess

command = ["rtk", "nix", "eval", "--offline", "--option", "eval-cache", "false", "--json"]
for pin in ["stable", "unstable"]:
    prefix = f"./dev#lib.tests.x86_64-linux.{pin}"
    fixtures = json.loads(subprocess.check_output(command + [prefix, "--apply", "builtins.attrNames"]))
    count = 0
    for fixture in fixtures:
        paths = [f"{prefix}.{fixture}"]
        if fixture in ["destinations", "priorities", "taggedDestinations", "validation"]:
            names = json.loads(subprocess.check_output(command + [paths[0], "--apply", "builtins.attrNames"]))
            paths = [f"{paths[0]}.{name}" for name in names]
        for path in paths:
            assert json.loads(subprocess.check_output(command + [path])) is True, path
            count += 1
    assert count == 100, (pin, count)
```

The temporary runner also records every command, exit code, output, and elapsed time in `/tmp/nixos-cross-config-issue-13-validation.CmzFQB/commands.jsonl`, and successful fixture paths in `results.json` alongside it.

All 200 public evaluation results passed: 100 per pin, including all 27 writable-tag cases and the factory regression on each pin. Every case exited 0 and returned JSON `true`.

## Diagnostics, cycles, and formatting

The existing diagnostic checks require each evaluation to fail and retain its expected reason and applicable sender, receiver, destination, and source-file fragments. Each cycle check runs the ordinary and tagged fixtures in separate evaluator processes and requires the native `error: infinite recursion encountered` message. These checks use the modern commands and declared dependencies from #12.

```bash
rtk nix build --offline --no-link --max-jobs 1 --print-build-logs \
  ./dev#checks.x86_64-linux.stable-diagnostics \
  ./dev#checks.x86_64-linux.unstable-diagnostics \
  ./dev#checks.x86_64-linux.stable-value-cycle \
  ./dev#checks.x86_64-linux.unstable-value-cycle \
  ./dev#checks.x86_64-linux.formatting
rtk git diff --check
```

The temporary runner captures the build output in `/tmp/nixos-cross-config-issue-13-validation.CmzFQB/checks.log` and its command, exit code, and elapsed time in `checks.json` alongside it.

Both commands exited 0. All five derivations built successfully. The cycle logs reported native recursion for both `value-cycle.nix` and `tagged-value-cycle.nix` on both pins, and all diagnostic cases retained their required context fragments. Formatting and `git diff --check` passed.

| Pin      | Public evaluation results | Diagnostic cases | Native cycles |
| -------- | ------------------------- | ---------------- | ------------- |
| Stable   | 100/100                   | 33/33            | 2/2           |
| Unstable | 100/100                   | 33/33            | 2/2           |

An independent source comparison against the starting commit confirmed that all 13 existing top-level let bindings and the returned module match after accounting for placement, indentation, and the `removeAttrs` qualification. The argument header also matches, and no `removeAttrs` binding was introduced. The existing regression suite verifies the reorganization's behavior.
