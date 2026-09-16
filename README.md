# nixos-cross-config

A NixOS library for configuration contributions between caller-supplied nodes. A sender declares settings for an existing writable option on a receiver, whose option type validates and merges those definitions.

The generated module receives `lib` from the consumer's NixOS evaluation. The [root flake](flake.nix) owns locked development inputs; the public factory remains usable through a plain Nix import without evaluating those inputs.

## Support

The library targets NixOS node collections using one nixpkgs revision. Development and CI definitions cover `x86_64-linux` and `aarch64-linux`, with evaluation tests against locked NixOS 26.05 and unstable inputs. The project has no VM suite or tagged release yet. See [CI and policy](docs/development.md#ci-and-policy) for shared checks and enrollment.

## Quickstart

With host Nix, flake commands, direnv with flake support, and shell integration configured:

```bash
direnv allow
nix flake check --no-update-lock-file
nix eval --json .#nixosConfigurations.proxy.config.services.nginx.virtualHosts \
  --apply 'hosts: hosts."app.example".locations."/".proxyPass'
# "http://192.0.2.10:8080"
```

See [development prerequisites](docs/development.md#prerequisites) for setup and the [minimal consumer](#minimal-consumer) for use in another flake.

## Factory

```nix
crossConfig.lib.mkModule {
  name = "application";
  inherit nodes optionPaths;
}
```

| Argument      | Contract                                                                                                             |
| ------------- | -------------------------------------------------------------------------------------------------------------------- |
| `name`        | The participant's key in `nodes`, independent of `networking.hostName`.                                              |
| `nodes`       | A caller-built attribute set whose participants expose their evaluated NixOS configuration as `nodes.<name>.config`. |
| `optionPaths` | One shared list of eligible option paths, each represented as a list of literal string segments.                     |

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

## Destinations and diagnostics

The forwarding surface is shared across heterogeneous nodes. Registration alone does not require every participant to declare an option or accept writes to it.

```nix
optionPaths = [
  [ "services" "nginx" "virtualHosts" ]
  [ "inventory" "serial" ]
];
```

A participant without `inventory.serial`, or with a read-only declaration for it, can still receive nginx contributions. Unused missing and read-only destinations are omitted from receiving definitions, including registered paths inside submodules. Defaults and receiver-local definitions remain intact. A false condition at a registered option contributes no definitions and leaves its payload unevaluated.

| Contribution                                  | Validation                                                                          |
| --------------------------------------------- | ----------------------------------------------------------------------------------- |
| Missing receiving option                      | The receiver's assertions fail.                                                     |
| Read-only receiving option                    | The receiver's assertions fail, even without a default or another definition.       |
| Unknown receiver identity                     | The sender's assertions fail; building the sender exposes the error.                |
| Path outside the forwarding surface           | The sender's module option check fails, including with an empty forwarding surface. |
| Incompatible value or conflicting definitions | The receiving option type reports its native type or merge error.                   |

System evaluation forces assertions through `config.system.build.toplevel`. Evaluations of individual configuration values must also check `config.assertions` to detect invalid destinations. A disabled receiver entry contributes nothing; an entry that remains present must name a member of the node collection.

Missing-option, read-only, type, and merge failures identify the sender, receiver, registered destination, and original definition filename when available. Forwarded definitions retain source filenames with contribution context appended:

```text
/path/to/application.nix (sender `application`, receiver `proxy`, destination `services.nginx.virtualHosts`)
```

Nested errors retain the receiving type's more specific option path. `--show-trace` exposes additional evaluation context, including the sender of an out-of-surface contribution. Diagnostics preserve normal option merging; exact original line and column attribution is not guaranteed.

## Definition properties

Override and ordering properties survive at each registered option and inside contributed attribute sets and submodules. The receiver merges contributed and local definitions using its ordinary option semantics.

Lower override priorities win. Definitions at the winning priority merge through the receiving type; incompatible scalar values still conflict.

| Definition                   | Override priority |
| ---------------------------- | ----------------- |
| Option declaration's default | 1500              |
| `lib.mkDefault value`        | 1000              |
| Ordinary assignment          | 100               |
| `lib.mkForce value`          | 50                |
| `lib.mkOverride n value`     | `n`               |

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

## Conditional integrations

`lib.mkIf` guards contributions at registered options:

```nix
# Sender, with networking.firewall.allowedTCPPorts registered.
crossConfig.nodes.receiver.networking.firewall.allowedTCPPorts =
  lib.mkIf config.services.openssh.enable [ 22 ];
```

A false condition contributes no definitions to the declared writable destination. Its payload values remain unevaluated; receiver-local settings and option defaults still apply.

`mkIf` and `mkMerge` also work around `crossConfig.nodes`, individual receiver entries, and intermediate path attributes. These containers select outgoing contributions during sender evaluation. Conditions and merges at registered options are also processed in the sender; nested values follow the receiving option type's semantics.

Several integrations can select the same receiver. `mkMerge` combines their receiver maps so each integration's definitions reach the receiving option:

```nix
# Sender, with services.nginx.virtualHosts registered.
let
  exports = [
    {
      receiver = "proxy";
      location = "/api";
      port = 8080;
      enable = true;
    }
    {
      receiver = "proxy";
      location = "/metrics";
      port = 9090;
      enable = true;
    }
  ];
in
{
  crossConfig.nodes = lib.mkMerge (
    map (export: lib.mkIf export.enable {
      ${export.receiver}.services.nginx.virtualHosts."app.example" = {
        locations.${export.location}.proxyPass =
          "http://192.0.2.10:${toString export.port}";
      };
    }) exports
  );
}
```

The proxy receives both locations. Disabling either export removes its contribution. Other senders and receiver-local refinements merge through the same receiving type.

## Sender context and receiving submodules

Expressions captured from the sender keep their lexical context. A function supplied to a receiving submodule gets that submodule's ordinary arguments, including its merged `config`. An explicit binding preserves access to the sender when a submodule also binds `config`:

```nix
# Sender module, with services.nginx.virtualHosts registered.
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

The receiver can refine the submodule:

```nix
services.nginx.virtualHosts."app.example".serverName = "public.example";
# The resulting serverAliases is [ "application.public.example" ].
```

Here `senderConfig.networking.hostName` belongs to the sender; `config.serverName` includes the receiver's refinement. Nested conditions can likewise depend on captured sender values or the receiving submodule's configuration. Submodule evaluation stays with the receiving option type. Receiver root imports and option declarations remain caller-owned and independent of received values.

## Node relationships and value dependencies

A sender can contribute to itself using its node identity. Self-targeted contributions merge with local definitions through the receiving option type:

```nix
# Node application, with networking.hosts registered.
networking.hosts."192.0.2.10" = [ "local.example" ];
crossConfig.nodes.application.networking.hosts."192.0.2.10" = [
  "service.example"
];
# Both names appear in nodes.application.config.networking.hosts."192.0.2.10".
```

Two nodes can also contribute independent values to one another. Neither node must finish evaluation before the other starts:

```nix
# Node alpha, with networking.hosts registered.
crossConfig.nodes.beta.networking.hosts."192.0.2.10" = [ "alpha.example" ];

# Node beta, in its own module.
crossConfig.nodes.alpha.networking.hosts."192.0.2.20" = [ "beta.example" ];
```

These relationships work for hosts and guests, including a container contributing to its parent and itself. Each participant imports the generated module with its collection identity.

An actual value-dependency cycle still fails with Nix's native `infinite recursion encountered` error. For example, each sender below reads the domain that only the other sender can supply:

```nix
# Node alpha module, with networking.domain registered.
{ config, ... }: {
  crossConfig.nodes.beta.networking.domain = config.networking.domain;
}

# Node beta module.
{ config, ... }: {
  crossConfig.nodes.alpha.networking.domain = config.networking.domain;
}
```

Forcing either receiving domain exposes the cycle. Cyclic values are not dropped or replaced with defaults. All participants remain accessible within one outer Nix computation; separate source repositories and per-node module evaluations fit this boundary.

## Minimal consumer

The runnable [example](./examples/minimal.nix) constructs an application and a proxy as NixOS container configurations. Both use the same Nixpkgs revision and import the public factory. The application contributes proxy settings for an illustrative backend at `192.0.2.10:8080`.

From a checkout, the root flake exposes the example:

```bash
nix eval --json .#nixosConfigurations.proxy.config.services.nginx.virtualHosts \
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

Node identities, the forwarding surface, receiver imports, and receiver option declarations must remain independent of received values. This includes `readOnly` metadata; receiver-local configuration can determine it. Ordinary receiver-local values and conditions can depend on contributions. Contributions define existing options. Root module imports and option declarations stay with the caller.

The receiver's generated NixOS configuration contains its contributions. Deploying that receiver through the consumer's normal deployment process activates the result. Node construction, discovery, globals aggregation, topology, service ownership, and deployment remain consumer responsibilities. The library provides no runtime exchange protocol, deployment orchestration, or required fleet framework.

## Development

The root flake supplies the shell, formatter, example, and non-VM checks. Run `nix fmt` and `nix flake check` from the repository root. [Development instructions](docs/development.md) cover prerequisites, tools, focused checks, and CI.

## Contributing

Follow [CONTRIBUTING.md](CONTRIBUTING.md) for the shared policy, PR workflow, public contracts, and release rules. [CHANGELOG.md](CHANGELOG.md) records unreleased changes and migration notes. Original code is licensed under [MIT](LICENSE).

## Documentation

- [Factory and contribution reference](#factory)
- [Minimal consumer](#minimal-consumer)
- [Development and checks](docs/development.md)
- [Domain glossary](CONTEXT.md)
- [Architectural decisions](docs/adr/)
- [Destination inspection design](docs/destination-inspection.md)
