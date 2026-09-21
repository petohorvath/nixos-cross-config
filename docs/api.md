# API reference

The primary interface is `nixosModules.default`, which declares `crossConfig.name`, `crossConfig.nodeCollection`, `crossConfig.optionPaths`, and the outgoing contribution option `crossConfig.nodes`. `lib.mkModule` remains a compatibility adapter. The [README quickstart](../README.md#quickstart) shows a complete example.

- [Module creation](#module-creation)
- [Compatibility adapter](#compatibility-adapter)
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
{
  imports = [ crossConfig.nixosModules.default ];
  crossConfig = {
    name = "application";
    nodeCollection = nodes;
    optionPaths = [ [ "services" "nginx" "virtualHosts" ] ];
  };
}
```

Include `nixosModules.default` in `nixosSystem.modules` or a module's `imports` on every participating node. Importing it enables both sending and receiving once the required settings are supplied. Ordinary integration needs no enable option, constructor, custom module arguments, or `specialArgs`.

All three settings are required:

| Option                       | Value                                                                                                                      |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `crossConfig.name`           | A string identifying this node's key in the collection, independently of `networking.hostName`.                            |
| `crossConfig.nodeCollection` | An opaque, lazy attribute set built by the caller. Each entry exposes its evaluated NixOS configuration through `.config`. |
| `crossConfig.optionPaths`    | A shared list of nonempty lists of literal string segments. An explicit empty outer list permits no contributions.         |

Every participating node must use the same node collection and normalized allowed-path set. Set each identity locally and import a common settings module for the collection and registrations:

```nix
let
  sharedSettings = {
    imports = [ crossConfig.nixosModules.default ];
    crossConfig.nodeCollection = nodes;
    crossConfig.optionPaths = [ [ "services" "nginx" "virtualHosts" ] ];
  };
in
{
  imports = [ sharedSettings ];
  crossConfig.name = "application";
}
```

The caller constructs `nodes`; the module does not discover nodes or combine different per-node registration sets. The collection type checks only the outer attribute set. It keeps entries lazy and does not recursively type-check, compare, copy, or merge evaluated configurations. Supply one collection definition at the winning option priority. Conflicting definitions at that priority fail; use `lib.mkDefault`, ordinary definitions, or `lib.mkForce` to select a collection.

The module receives `lib` from the node's NixOS evaluation. It does not evaluate development inputs or require flake-parts. With a checkout at `./nixos-cross-config`, a plain Nix import provides the module:

```nix
((import ./nixos-cross-config/flake.nix).outputs { }).nixosModules.default
```

The root flake has one development `nixpkgs` input, which consumers can share with their own selected revision:

```nix
inputs.crossConfig.inputs.nixpkgs.follows = "nixpkgs";
```

Use the same input name as the consuming flake; `crossConfig` matches the README quickstart. Keep one nixpkgs revision per node collection. The input selects the shell, formatter, packages, checks, focused fixtures, and examples; the module still receives its `lib` from the receiver. Compatibility uses invocation-specific overrides, so no second compatibility input enters the consumer's lock graph. See [development instructions](development.md#compatibility-checks) for exact-revision commands and the policy coverage boundary.

## Compatibility adapter

Existing consumers can keep the required constructor signature:

```nix
crossConfig.lib.mkModule { inherit name nodes optionPaths; }
```

The adapter imports the same lower-level module and supplies ordinary definitions for `crossConfig.name`, `crossConfig.nodeCollection`, and `crossConfig.optionPaths`. It preserves the receiver's `lib` and the existing plain-import access pattern:

```nix
((import ./nixos-cross-config/flake.nix).outputs { }).lib.mkModule
```

To migrate, replace the constructor import with `nixosModules.default`, move `name` to `crossConfig.name`, `nodes` to `crossConfig.nodeCollection`, and `optionPaths` to `crossConfig.optionPaths`. Keep outgoing `crossConfig.nodes` assignments unchanged. The new path validation and reserved-root restriction apply to both interfaces; relocate destinations beneath an ordinary receiving namespace when migrating a root named `crossConfig` or `_module`.

## Allowed option paths

`crossConfig.optionPaths` selects which options can receive contributions:

```nix
crossConfig.optionPaths = [
  [ "services" "nginx" "virtualHosts" ]
  [ "environment" "etc" "application.conf" "text" ]
];
```

Each string is one attribute name. `"application.conf"` contains a literal dot; it is one segment. Paths can identify options inside submodules. The receiver's own modules supply the option declarations.

The setting has no implicit empty default. Set `crossConfig.optionPaths = [ ];` explicitly to permit no contributions. Empty inner paths, non-list paths, and non-string segments are invalid.

Several shared modules can supply registrations. List definitions merge at the winning option priority and then complete paths are deduplicated, preserving their first occurrence. Repeating a list-valued destination delivers each contribution only once. An ordinary list replaces `lib.mkDefault` lists; `lib.mkForce` replaces ordinary lists. Ordering helpers such as `lib.mkBefore` order surviving registrations before deduplication.

Paths whose first segment is `crossConfig` or `_module` are rejected, including unused registrations, because those namespaces configure the module and module-system internals. Nested attributes and tags with these names remain supported, for example `[ "inventory" "_module" "value" ]`.

Registrations are structural configuration. Literal paths, shared list composition, override priorities, and conditions based on independent setup values are supported. Paths must remain independent of receiving configuration: even a locally defined flag inside a generated receiving namespace can introduce a dependency cycle. Register paths unconditionally where possible and put service-dependent conditions on the contributions themselves, as in [conditional contributions](#conditional-contributions). The module does not add an evaluation stage to discover registrations.

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

This also works for hosts and guests, including a container contributing to its parent and itself. Each node imports `nixosModules.default` and supplies its own `crossConfig.name`, with the same collection and normalized path set.

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

Missing required settings and invalid setting types fail with the relevant `crossConfig` option name. Checking assertions also checks required settings on idle nodes with no contributions. Reserved-root errors identify the offending registration and the node identity when available. Setting validation applies through the compatibility adapter as well.

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
