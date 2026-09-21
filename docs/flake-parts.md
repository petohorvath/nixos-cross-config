# Flake-parts consumers

Import `crossConfig.flakeModules.default` to configure shared settings at flake scope. The adapter provides `config.flake.nixosModules.crossConfig`; each participating node explicitly imports that NixOS module and supplies its own `crossConfig.name`. The caller constructs the nodes. Importing the adapter alone does not add configuration to existing nodes.

## Default collection

The following flake constructs two NixOS containers. The application contributes a virtual host to the proxy. The adapter's `crossConfig.nodeCollection` defaults lazily to this consumer's `flake.nixosConfigurations`, including both nodes:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  inputs.crossConfig.url = "github:petohorvath/nixos-cross-config";
  inputs.crossConfig.inputs.nixpkgs.follows = "nixpkgs";

  outputs = inputs@{ nixpkgs, crossConfig, ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { config, ... }:
      {
        imports = [ crossConfig.flakeModules.default ];
        systems = [ ];
        crossConfig.optionPaths = [ [ "services" "nginx" "virtualHosts" ] ];

        flake.nixosConfigurations = builtins.mapAttrs (name: module:
          nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              config.flake.nixosModules.crossConfig
              {
                crossConfig.name = name;
                boot.isContainer = true;
                networking.hostName = "${name}-container";
                system.stateVersion = "26.05";
              }
              module
            ];
          }
        ) {
          application.crossConfig.nodes.proxy.services.nginx.virtualHosts."app.example" = {
            locations."/".proxyPass = "http://192.0.2.10:8080";
          };
          proxy.services.nginx = {
            enable = true;
            virtualHosts."app.example".serverAliases = [ "www.app.example" ];
          };
        };
      }
    );
}
```

Save this as `flake.nix` in a new directory. If the directory is in Git, track the file before evaluation. With Nix and the `nix-command` and `flakes` features enabled, evaluate the proxy's result:

```bash
nix eval --json .#nixosConfigurations.proxy.config.services.nginx.virtualHosts \
  --apply 'hosts: hosts."app.example".locations."/".proxyPass'
# "http://192.0.2.10:8080"
```

The command creates a lockfile for the consumer's inputs. The backend address is illustrative; evaluation does not start an application or deploy either node. The [repository example](../examples/flake-parts.nix) uses this setup and runs in the existing evaluation harness.

Both settings and the configured module are system-independent, so they belong outside `perSystem`. `systems = [ ];` leaves per-system outputs unused in this example; each node's builder selects its platform. Outgoing `crossConfig.nodes` contributions and the required node identity remain in NixOS modules. Identities can differ from hostnames.

## Explicit collection

Set flake-level `crossConfig.nodeCollection` to select a subset or include caller-owned guests absent from `nixosConfigurations`. With the same inputs, replace the flake-parts module above with this body:

```nix
{ config, ... }:
let
  mkNode = name: module: nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      config.flake.nixosModules.crossConfig
      {
        crossConfig.name = name;
        boot.isContainer = true;
        networking.hostName = "${name}-container";
        system.stateVersion = "26.05";
      }
      module
    ];
  };
  nodes = {
    host = mkNode "host" { };
    guest = mkNode "guest" {
      crossConfig.nodes.host.networking.hosts."192.0.2.30" = [ "guest.example" ];
    };
  };
in
{
  imports = [ crossConfig.flakeModules.default ];
  systems = [ ];
  crossConfig = {
    optionPaths = [ [ "networking" "hosts" ] ];
    nodeCollection = nodes;
  };
  flake.nixosConfigurations = { inherit (nodes) host; };
}
```

Only `host` appears in the standard flake output; the caller-owned collection also contains `guest`. The host's `config.networking.hosts."192.0.2.30"` contains `[ "guest.example" ]`. The explicit collection replaces the default without scanning nodes or inspecting receiving values. Guest deployment and construction remain the caller's responsibility.

## Shared settings and priorities

`crossConfig.optionPaths` is required at flake scope. Set `[ ]` explicitly when no contributions are allowed. Each path is a nonempty list of literal string segments: `[ "environment" "etc" "application.conf" "text" ]` contains a filename with a literal dot. Empty inner lists and non-string segments are invalid. The roots `crossConfig` and `_module` are reserved; these names remain valid below another receiving root.

Shared flake modules can each define `crossConfig.optionPaths`. Lists merge at the winning priority, ordering helpers apply, and duplicate complete paths collapse in first-occurrence order. An ordinary definition replaces `mkDefault` registrations, and `mkForce` replaces ordinary registrations. One node collection definition must remain at the winning priority; evaluated collections are opaque and are never recursively merged or compared.

The configured NixOS module supplies the resolved paths and collection with `lib.mkDefault`. Extend shared paths through flake-level modules so every participant receives the same normalized set. An ordinary node-level list replaces the entire supplied default, including when that list is empty; it does not append to the shared list. Deliberate node-level overrides must preserve the same collection and normalized path set across all participants.

Path registrations must remain independent of receiving configuration. Prefer unconditional registrations and put service-dependent conditions on contributions. Moving composition to flake scope does not remove these [registration-dependency limits](api.md#allowed-option-paths).

The configured module receives `lib` from the node's NixOS evaluation. The standalone module and compatibility constructor remain usable without flake-parts; see the [API reference](api.md#flake-parts-adapter) for export and plain-import contracts.
