# nixos-cross-config

A NixOS library for configuration contributions between caller-supplied nodes. A sender declares settings for an existing writable option on a receiver, whose option type validates and merges those definitions.

The consumer flake has zero required inputs. The generated module receives `lib` from the consumer's NixOS evaluation; test and formatter dependencies live in the separate [development flake](./dev/flake.nix).

## Factory

```nix
crossConfig.lib.mkModule {
  name = "application";
  inherit nodes optionPaths;
}
```

| Argument | Contract |
| --- | --- |
| `name` | The participant's key in `nodes`, independent of `networking.hostName`. |
| `nodes` | A caller-built attribute set whose participants expose their evaluated NixOS configuration as `nodes.<name>.config`. |
| `optionPaths` | One shared list of eligible option paths, each represented as a list of literal string segments. |

Every participant imports its generated module. Importing enables both sending and receiving; there is no enable option.

```nix
optionPaths = [
  [ "services" "nginx" "virtualHosts" ]
  [ "environment" "etc" "application.conf" "text" ]
];
```

The segment `"application.conf"` denotes one attribute containing a dot. Paths identify receiving destinations; the receiver's own modules supply their option declarations.

Outgoing definitions use ordinary nested assignments:

```nix
crossConfig.nodes.proxy.services.nginx.virtualHosts."app.example" = {
  locations."/".proxyPass = "http://192.0.2.10:8080";
};
```

The proxy can add local settings to the same virtual host:

```nix
services.nginx.virtualHosts."app.example".serverAliases = [
  "www.app.example"
];
```

Multiple senders and receiver-local definitions merge through the receiving option type. Locality grants no extra precedence: incompatible scalar definitions at equal priority fail. These are [NixOS option merging semantics](https://nixos.org/manual/nixos/stable/#sec-option-definitions).

`crossConfig.nodes` is a declaration interface. The observable result is `nodes.<receiver>.config`; the transport's evaluated representation is internal.

## Definition properties

Override and ordering properties survive at each registered option and inside contributed attribute sets and submodules. The receiver merges contributed and local definitions using its ordinary option semantics.

Lower override priorities win. Definitions at the winning priority merge through the receiving type; incompatible scalar values still conflict.

| Definition | Override priority |
| --- | --- |
| Option declaration's default | 1500 |
| `lib.mkDefault value` | 1000 |
| Ordinary assignment | 100 |
| `lib.mkForce value` | 50 |
| `lib.mkOverride n value` | `n` |

A contributed default allows a receiver refinement:

```nix
# Sender, with networking.domain registered.
crossConfig.nodes.receiver.networking.domain =
  lib.mkDefault "service.example";

# Receiver: the resulting domain is "site.example".
networking.domain = "site.example";
```

Nested properties follow the same rules. With `services.nginx.virtualHosts` registered, a sender can supply a default for one location:

```nix
crossConfig.nodes.proxy.services.nginx.virtualHosts."app.example" = {
  locations."/".proxyPass = lib.mkDefault "http://192.0.2.10:8080";
};
```

List ordering is independent of override priority. `mkBefore` uses order 500, ordinary definitions use 1000, and `mkAfter` uses 1500. `mkOrder n value` supplies a custom order. Lower orders appear first among the surviving definitions, before any option-specific `apply` processing.

```nix
# Sender, with networking.search registered.
crossConfig.nodes.receiver.networking.search =
  lib.mkBefore [ "service.example" ];

# Receiver: the result is [ "service.example" "site.example" ].
networking.search = [ "site.example" ];
```

Overrides can contain ordering properties, such as `lib.mkForce (lib.mkAfter [ "service.example" ])`. Multiple senders and receiver-local definitions participate in the same priority and ordering rules.

Properties on `crossConfig.nodes` or `crossConfig.nodes.<receiver>` select outgoing contributions during sender evaluation. Their priorities do not become receiving-option priorities:

```nix
# Select this outgoing receiver map over weaker maps in the sender.
crossConfig.nodes = lib.mkForce {
  # The receiving domain remains a default that local settings can override.
  receiver.networking.domain = lib.mkDefault "service.example";
};
```

The receiving guarantee starts at each registered option. Properties intended to control receiving precedence belong at that option or within its nested values.

## Minimal consumer

The runnable [example](./examples/minimal.nix) constructs an application and a proxy as NixOS container configurations. Both use the same Nixpkgs revision and import the public factory. The application contributes proxy settings for an illustrative backend at `192.0.2.10:8080`.

From a checkout, the development flake exposes the example:

```bash
nix eval --json ./dev#nixosConfigurations.proxy.config.services.nginx.virtualHosts \
  --apply 'hosts: hosts."app.example".locations."/".proxyPass'
# "http://192.0.2.10:8080"
```

A consumer flake can evaluate the same example:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.crossConfig.url = "github:petohorvath/nixos-cross-config";

  outputs = { nixpkgs, crossConfig, ... }: {
    nixosConfigurations = import "${crossConfig}/examples/minimal.nix" {
      inherit crossConfig nixpkgs;
    };
  };
}
```

The consumer's `flake.lock` pins its selected revisions. Existing host and guest builders can supply their own collection instead of the example's builder. The [host and guest fixture](./tests/host-guest.nix) includes a guest produced by NixOS's `containers` option.

## Evaluation and deployment

V1 targets NixOS, with one Nixpkgs revision per node collection. All participating configurations must be accessible within one outer Nix computation. Separate source repositories and per-node evaluations fit that boundary; mixed-revision collections are outside the v1 contract.

Node identities, the forwarding surface, receiver imports, and receiver option declarations must remain independent of received values. Contributions define existing options. Root module imports and option declarations stay with the caller.

The receiver's generated NixOS configuration contains its contributions. Deploying that receiver through the consumer's normal deployment process activates the result. Node construction, discovery, globals aggregation, topology, service ownership, and deployment remain consumer responsibilities. The library provides no runtime exchange protocol, deployment orchestration, or required fleet framework.

## Checks

The [locked development inputs](./dev/flake.lock) select NixOS 26.05 and unstable separately. The same public fixtures run once per revision; each collection uses only that revision.

```bash
# New files must be tracked before Git-backed flake evaluation.
git add <new-files>

# One fixture, including native NixOS option typechecking.
nix eval --json ./dev#lib.tests.x86_64-linux.stable.merging
nix eval --json ./dev#lib.tests.x86_64-linux.stable.priorities

# Full evaluation suite on stable and unstable, plus formatting.
nix flake check ./dev

# Formatting from the development flake.
(cd dev && nix fmt -- ..)
```

Each complete collection suite can also run in a separate evaluator process to reduce peak memory use:

```bash
nix build --no-link ./dev#checks.x86_64-linux.stable
nix build --no-link ./dev#checks.x86_64-linux.unstable
nix build --no-link ./dev#checks.x86_64-linux.formatting
```

Fixtures force received values, host and guest assertions, and the example's system derivation paths. Priority and ordering fixtures cover whole options, nested values, multiple senders, receiver refinements, and transport selection. Expected failures force ordinary and explicit-priority conflicts, nested conflicts, invalid option types, and a contributed assertion through the receiver's system build. An individual failure can be inspected directly:

```bash
nix eval --json ./dev#lib.failures.x86_64-linux.stable.localConflict
```

## Current scope

Contributions preserve whole-option and nested override priorities and list ordering. The full conditional and cyclic-node contracts and destination diagnostics remain follow-up work. Until destination validation is complete, every participant must provide the registered writable destinations.

The implementation plan also includes migration of the existing `nixos-config` consumer. Work is tracked in GitHub Issues.

- [Domain glossary](./CONTEXT.md)
- [Architectural decisions](./docs/adr/)

## Implementation plan

1. [Forward contributions through a caller-owned node collection](https://github.com/petohorvath/nixos-cross-config/issues/1) — implemented.
2. [Preserve override priorities and ordering in contributions](https://github.com/petohorvath/nixos-cross-config/issues/2) — implemented.
3. [Preserve conditional contributions and sender context](https://github.com/petohorvath/nixos-cross-config/issues/3)
4. [Support self-targeted and reciprocal node contributions](https://github.com/petohorvath/nixos-cross-config/issues/4)
5. [Validate destinations and report contribution origins](https://github.com/petohorvath/nixos-cross-config/issues/5)
6. [Adopt the library in the consumer and migrate Vaultwarden](https://github.com/petohorvath/nixos-cross-config/issues/6)
7. [Migrate the remaining nginx publication integrations](https://github.com/petohorvath/nixos-cross-config/issues/7)
8. [Migrate metrics and log access contributions](https://github.com/petohorvath/nixos-cross-config/issues/8)
9. [Remove legacy forwarding after the consumer cutover](https://github.com/petohorvath/nixos-cross-config/issues/9)
