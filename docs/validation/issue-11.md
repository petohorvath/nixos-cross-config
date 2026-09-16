# Factory source attribution validation

Issue [#11](https://github.com/petohorvath/nixos-cross-config/issues/11) gives modules returned by the public factory their defining `lib/mk-module.nix` source location. The wrapper uses the receiver's `lib.setDefaultModuleLocation`, matching the composition in flake-parts' [importApply implementation](https://github.com/hercules-ci/flake-parts/blob/main/lib.nix#L261). The factory keeps its required `name`, `nodes`, and `optionPaths` arguments and adds no consumer inputs. The receiving module system still supplies the implementation's ordinary module arguments.

Validation started from completed issue #10 at commit `0e588059ed1288c1bbed6274b77f3b9eda81c707`. Checks ran on `x86_64-linux` with Nix 2.34.6 against locked stable `c3eea5b2156db11c7eeeada3dc737711255b253e` and unstable `ef34387ddd751e1ab8857adf4676492d32eb24ec`. The shared test runner registers the new regression for both exported systems; execution on `aarch64-linux` was not attempted.

## Regression

The new [public-factory fixture](../../tests/mk-module.nix) constructs two nodes with separate module evaluations. Each evaluation supplies a marked `lib`, ordinary `name`, `nodes`, and `optionPaths` arguments that differ from the factory's arguments, and an argument through `_module.args`. The fixture checks the exact declaration source path, use of each receiver's library, public factory argument shape, ordinary argument availability, distinct node identities, reciprocal contributions, local list merging, ordering, and the original [sender fixture filename](../../tests/fixtures/factory-node.nix) with contribution context.

The registered fixture was run before changing the public factory. Both commands exited 1 at the declaration assertion: the actual source was `<unknown-file>`, while the expected source was the checkout's store path ending in `/lib/mk-module.nix`.

```bash
rtk nix eval --offline --option eval-cache false --json \
  ./dev#lib.tests.x86_64-linux.stable.mkModule
rtk nix eval --offline --option eval-cache false --json \
  ./dev#lib.tests.x86_64-linux.unstable.mkModule
```

After adding the wrapper, both commands exited 0 and returned `true`. The complete fixture also checks that contributed definition filenames remain attached to the sender file instead of adopting the library's declaration filename.

## Public behavior

The focused public behavior checks run in separate evaluator processes on each pin. Coverage includes forwarding, multiple senders and receiver-local merging, captured sender context, self-targeting, reciprocal contributions, host/guest identities, the minimal consumer, the NixOS writable-tag integration, and every existing positive destination-validation case. The new factory regression is included in the same run.

```python
import json
import subprocess

command = ["rtk", "nix", "eval", "--offline", "--option", "eval-cache", "false", "--json"]
fixtures = [
    "mkModule",
    "forwarding",
    "merging",
    "senderContext",
    "selfTarget",
    "reciprocal",
    "hostGuest",
    "example",
    "taggedDestinations.nixos",
]
for pin in ["stable", "unstable"]:
    prefix = f"./dev#lib.tests.x86_64-linux.{pin}"
    names = json.loads(subprocess.check_output(
        command + [f"{prefix}.destinations", "--apply", "builtins.attrNames"]
    ))
    paths = [f"{prefix}.{fixture}" for fixture in fixtures]
    paths.extend(f"{prefix}.destinations.{name}" for name in names)
    for path in paths:
        assert json.loads(subprocess.check_output(command + [path])) is True, path
```

## Diagnostics and formatting

The existing diagnostic derivations retain their separate evaluator processes and fragment assertions. They cover invalid destinations, native type and merge failures, unknown receivers, unregistered destinations, and contribution identities and filenames, including the writable-tag cases added for #10. The unchanged diagnostic runner's CLI modernization remains assigned to #12.

```bash
rtk nix build --offline --no-link --max-jobs 1 \
  ./dev#checks.x86_64-linux.stable-diagnostics \
  ./dev#checks.x86_64-linux.unstable-diagnostics \
  ./dev#checks.x86_64-linux.formatting
rtk git diff --check
```

All 42 focused public evaluations passed. Both diagnostic derivations exited 0, retaining all 66 expected failures and their required context fragments. Formatting and `git diff --check` also passed.

| Pin | Factory and public behavior | Diagnostic cases |
| --- | --- | --- |
| Stable | 21/21 | 33/33 |
| Unstable | 21/21 | 33/33 |
