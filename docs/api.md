# API reference

The public API consists of the `lib.mkModule` function and the `crossConfig.nodes` option declared by its returned module. The [README quickstart](../README.md#quickstart) shows a complete example.

- [Module creation](#module-creation)
- [Allowed option paths](#allowed-option-paths)
- [Contributions and results](#contributions-and-results)
- [Override priorities and list ordering](#override-priorities-and-list-ordering)
- [Conditional contributions](#conditional-contributions)
- [Sender values and receiving submodules](#sender-values-and-receiving-submodules)
- [Self and reciprocal contributions](#self-and-reciprocal-contributions)
- [Validation and errors](#validation-and-errors)
- [Evaluation and deployment](#evaluation-and-deployment)

## Module creation

```nix
crossConfig.lib.mkModule {
  name = "application";
  inherit nodes optionPaths;
}
```

`mkModule` returns a NixOS module. Include it in `nixosSystem.modules` or a module's `imports` on every node in the collection. Importing it enables both sending and receiving; there is no enable option.

All arguments are required:

| Argument      | Value                                                                                                                |
| ------------- | -------------------------------------------------------------------------------------------------------------------- |
| `name`        | The node's key in `nodes`. This identity is independent of `networking.hostName`.                                    |
| `nodes`       | An attribute set built by the caller. Each entry exposes its evaluated NixOS configuration as `nodes.<name>.config`. |
| `optionPaths` | The shared list of allowed option paths. Each path is a list of literal string segments.                             |

Pass the same `nodes` and `optionPaths` to every node. Use the appropriate `name` for each node.

The returned module receives `lib` from the node's NixOS evaluation. It does not use the flake's development inputs to select that library. With a checkout at `./nixos-cross-config`, this expression also provides the function through a plain Nix import:

```nix
((import ./nixos-cross-config/flake.nix).outputs { }).lib.mkModule
```

Accessing `lib.mkModule` this way does not evaluate the development input. The root flake has one `nixpkgs` input, which consumers can share with their own selected revision:

```nix
inputs.crossConfig.inputs.nixpkgs.follows = "nixpkgs";
```

Use the same input name as the consuming flake; `crossConfig` matches the README quickstart. Keep one nixpkgs revision per node collection. The input selects the shell, formatter, packages, checks, focused fixtures, and examples; the returned module still receives its `lib` from the receiver. Compatibility uses invocation-specific overrides, so no second compatibility input enters the consumer's lock graph. See [development instructions](development.md#compatibility-checks) for exact-revision commands and the policy coverage boundary.

## Allowed option paths

`optionPaths` selects which options can receive contributions:

```nix
optionPaths = [
  [ "services" "nginx" "virtualHosts" ]
  [ "environment" "etc" "application.conf" "text" ]
];
```

Each string is one attribute name. `"application.conf"` contains a literal dot; it is one segment. Paths can identify options inside submodules. The receiver's own modules supply the option declarations.

The list is shared across the node collection. Listing a path does not require every node to declare that option. A node can have a missing or read-only option at a listed path while it receives contributions at other paths. A contribution to a missing or read-only option fails validation on that receiver.

Unused missing or read-only paths add no receiving definitions. This also applies to paths inside submodules. Option defaults and local definitions still apply.

## Contributions and results

`crossConfig.nodes` defaults to `{ }`. Define contributions with ordinary nested assignments in a sender's module:

```nix
# Sender, with services.nginx.virtualHosts in optionPaths.
crossConfig.nodes.proxy.services.nginx.virtualHosts."app.example" = {
  locations."/".proxyPass = "http://192.0.2.10:8080";
};
```

The proxy can define more settings for the same virtual host:

```nix
# Receiver.
services.nginx.virtualHosts."app.example".serverAliases = [
  "www.app.example"
];
```

The receiver's option type validates and merges contributions from all senders with local definitions. A local definition has no extra priority. Incompatible scalar definitions at equal priority fail under the normal [NixOS option merging rules](https://nixos.org/manual/nixos/stable/#sec-option-definitions).

Read the result from `nodes.<receiver>.config`. In this example, `nodes.proxy.config.services.nginx.virtualHosts."app.example"` contains both settings. `crossConfig.nodes` declares outgoing contributions; its evaluated representation is internal.

## Override priorities and list ordering

Override priorities and list ordering apply at each allowed option path and inside contributed attribute sets and submodules. The receiver uses its ordinary option semantics to merge contributed and local definitions.

Lower override priorities win. Definitions at the winning priority merge through the receiving type; incompatible scalar values still conflict.

| Definition                   | Override priority |
| ---------------------------- | ----------------- |
| Option declaration's default | 1500              |
| `lib.mkDefault value`        | 1000              |
| Ordinary assignment          | 100               |
| `lib.mkForce value`          | 50                |
| `lib.mkOverride n value`     | `n`               |

A sender can supply a default that the receiver overrides:

```nix
# Sender, with networking.domain in optionPaths.
crossConfig.nodes.receiver.networking.domain =
  lib.mkDefault "service.example";

# Receiver: the resulting domain is "site.example".
networking.domain = "site.example";
```

Nested definitions follow the same rules. With `services.nginx.virtualHosts` in `optionPaths`, a sender can supply a default for one location:

```nix
crossConfig.nodes.proxy.services.nginx.virtualHosts."app.example" = {
  locations."/".proxyPass = lib.mkDefault "http://192.0.2.10:8080";
};
```

List ordering is independent of override priority. `lib.mkBefore` uses order 500, ordinary definitions use 1000, and `lib.mkAfter` uses 1500. `lib.mkOrder n value` supplies a custom order. Lower orders appear first among the surviving definitions, before any option-specific `apply` processing.

```nix
# Sender, with networking.search in optionPaths.
crossConfig.nodes.receiver.networking.search =
  lib.mkBefore [ "service.example" ];

# Receiver: the result is [ "service.example" "site.example" ].
networking.search = [ "site.example" ];
```

Overrides can contain ordering properties, such as `lib.mkForce (lib.mkAfter [ "service.example" ])`. Multiple senders and local definitions follow the same priority and ordering rules.

### Priorities on receiver entries

Properties on `crossConfig.nodes` or `crossConfig.nodes.<receiver>` select outgoing contributions during sender evaluation. Those priorities do not become priorities on the receiving option:

```nix
# Select this receiver map over weaker maps in the sender.
crossConfig.nodes = lib.mkForce {
  # Local settings on the receiver can still override this default.
  receiver.networking.domain = lib.mkDefault "service.example";
};
```

To control priority on the receiver, put the property at the allowed option path or inside its nested values.

## Conditional contributions

Use `lib.mkIf` at an allowed option path to make a contribution conditional:

```nix
# Sender, with networking.firewall.allowedTCPPorts in optionPaths.
crossConfig.nodes.receiver.networking.firewall.allowedTCPPorts =
  lib.mkIf config.services.openssh.enable [ 22 ];
```

A false condition contributes no definitions and leaves its payload unevaluated. The receiver's local settings and option defaults still apply.

`lib.mkIf` and `lib.mkMerge` also work around `crossConfig.nodes`, individual receiver entries, and intermediate path attributes. These select outgoing contributions during sender evaluation. Conditions and merges at the allowed option paths are also processed in the sender. Conditions inside nested values follow the receiving option type's semantics.

Several contributions can target the same receiver and option. For example, with `services.nginx.virtualHosts` in `optionPaths`:

```nix
crossConfig.nodes = lib.mkMerge [
  {
    proxy.services.nginx.virtualHosts."app.example" = {
      locations."/api".proxyPass = "http://192.0.2.10:8080";
    };
  }
  {
    proxy.services.nginx.virtualHosts."app.example" = {
      locations."/metrics".proxyPass = "http://192.0.2.10:9090";
    };
  }
];
```

The proxy receives both locations. Each contribution can have its own `lib.mkIf` condition. Contributions from other senders and local definitions merge through the same receiving type.

## Sender values and receiving submodules

Expressions that refer to the sender's configuration keep that reference when contributed. A function supplied as a receiving submodule gets that submodule's ordinary arguments, including its merged `config`.

Use a separate binding for the sender's `config` when the submodule also binds `config`:

```nix
# Sender module, with services.nginx.virtualHosts in optionPaths.
{ config, lib, ... }:
let
  senderConfig = config;
in
{
  networking.hostName = "application";
  crossConfig.nodes.proxy.services.nginx.virtualHosts."app.example" =
    { config, ... }: {
      serverName = lib.mkDefault "app.example";
      serverAliases = [
        "${senderConfig.networking.hostName}.${config.serverName}"
      ];
    };
}
```

The receiver can set a different server name:

```nix
services.nginx.virtualHosts."app.example".serverName = "public.example";
# The resulting serverAliases is [ "application.public.example" ].
```

Here `senderConfig.networking.hostName` belongs to the sender. `config.serverName` is the receiving submodule's merged value, which includes the local definition. Nested conditions can also depend on sender values or the receiving submodule's configuration.

## Self and reciprocal contributions

A sender can contribute to itself using its node identity. With `networking.hosts` in `optionPaths`:

```nix
# Node application.
networking.hosts."192.0.2.10" = [ "local.example" ];
crossConfig.nodes.application.networking.hosts."192.0.2.10" = [
  "service.example"
];
# Both names appear in nodes.application.config.networking.hosts."192.0.2.10".
```

Two nodes can also contribute independent values to each other. Neither node must finish evaluation before the other starts:

```nix
# Node alpha, with networking.hosts in optionPaths.
crossConfig.nodes.beta.networking.hosts."192.0.2.10" = [ "alpha.example" ];

# Node beta, in its own module.
crossConfig.nodes.alpha.networking.hosts."192.0.2.20" = [ "beta.example" ];
```

This also works for hosts and guests, including a container contributing to its parent and itself. Each node imports the module returned by `mkModule` with its own node identity.

An actual cycle between values still fails with Nix's native `infinite recursion encountered` error. In the following example, each sender reads the domain that only the other sender can supply:

```nix
# Node alpha module, with networking.domain in optionPaths.
{ config, ... }: {
  crossConfig.nodes.beta.networking.domain = config.networking.domain;
}

# Node beta module.
{ config, ... }: {
  crossConfig.nodes.alpha.networking.domain = config.networking.domain;
}
```

Evaluating either receiving domain exposes the cycle. Cyclic values are not dropped or replaced with defaults.

## Validation and errors

| Contribution                                  | Validation                                                                             |
| --------------------------------------------- | -------------------------------------------------------------------------------------- |
| Missing receiving option                      | The receiver's assertions fail.                                                        |
| Read-only receiving option                    | The receiver's assertions fail, even without a default or another definition.          |
| Unknown receiver identity                     | The sender's assertions fail. Building the sender exposes the error.                   |
| Path outside `optionPaths`                    | The sender's module option check fails. This also applies when `optionPaths` is empty. |
| Incompatible value or conflicting definitions | The receiving option type reports its native type or merge error.                      |

Evaluating `config.system.build.toplevel` checks NixOS assertions. When evaluating individual configuration values, also check `config.assertions` to detect invalid destinations. Reading a contributed value alone does not establish that the configuration is valid.

A disabled receiver entry contributes nothing. An entry that remains present must name a node in the collection, even if a condition disables the contribution at an option path.

Missing-option, read-only, type, and merge failures identify the sender, receiver, allowed option path, and original definition filename when available. Contributed definitions retain source filenames with contribution context appended:

```text
/path/to/application.nix (sender `application`, receiver `proxy`, destination `services.nginx.virtualHosts`)
```

Nested errors retain the receiving type's more specific option path. `--show-trace` provides additional evaluation context, including the sender of a contribution outside `optionPaths`. Exact original line and column attribution is not guaranteed.

## Evaluation and deployment

The library targets NixOS with one nixpkgs revision per node collection. All participating configurations must be accessible within one Nix computation. Source modules can come from separate repositories, and each node can have its own module evaluation. Collections with mixed nixpkgs revisions are outside the supported contract.

Node identities, allowed option paths, receiver imports, and receiver option declarations must be independent of received values. This also applies to `readOnly` metadata, which can depend on the receiver's local configuration. Ordinary option values and conditions on the receiver can depend on contributions.

Contributions define existing options. The caller supplies each receiver's root module imports and option declarations. [ADR 0003](adr/0003-contribute-existing-option-definitions.md) explains this boundary.

The receiver's resulting NixOS configuration contains its contributions. Deploy the receiver through the usual deployment process to activate them. Node construction, discovery, shared data aggregation, topology, service ownership, and deployment remain the caller's responsibility. The library does not provide a runtime exchange protocol or require a particular tool for building the node collection.
