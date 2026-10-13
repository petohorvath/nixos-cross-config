# nixos-cross-config

nixos-cross-config is a NixOS module that lets one NixOS configuration define options on another configuration in the same flake or evaluation. An application's modules can define the nginx virtual host it needs on a proxy, and NixOS merges that definition with the proxy's own settings. Configuration that one machine needs from another can live with the service that needs it, so the receiving host doesn't have to repeat it.

## Overview

Each participating NixOS configuration is a **node**, and the caller builds all of them into one **node collection**. Every node imports the module and sets its **node identity**: its name in the collection, which can differ from its hostname. A **sender** defines a **contribution** under `crossConfig.contributions.<receiver>`, and the **receiver**'s configuration includes those definitions. A node can be both, including a receiver of its own contributions.

Contributions are allowed only at the **allowed option paths** that every node shares in `crossConfig.optionPaths`. The receiver's own modules must declare each option that receives contributions; contributions define existing options and never add imports or declarations. Contributed and local definitions merge under ordinary NixOS rules, so `lib.mkDefault`, `lib.mkForce`, `lib.mkIf`, and list ordering work as they do in any module, and a local definition has no extra priority.

Everything happens during evaluation. The receiver's resulting configuration contains its contributions and deploys through the usual process; there is no runtime exchange between machines. The [glossary](GLOSSARY.md) defines these terms. The [architectural decisions](docs/adr/) record the reasoning behind the design, and the [destination inspection design](docs/destination-inspection.md) explains how receiving options are checked.

## Entry points

| Flake output           | Plain Nix import                             | Purpose                                                                                |
| ---------------------- | -------------------------------------------- | -------------------------------------------------------------------------------------- |
| `nixosModules.default` | [`nixos/module.nix`](nixos/module.nix)       | The NixOS module. Import it on every participating node.                               |
| `flakeModules.default` | [`flake-module.nix`](flake-module.nix)       | Optional flake-parts module that shares the collection settings at flake scope.        |
| `lib.mkModule`         | [`(import ./lib).mkModule`](lib/default.nix) | Compatibility constructor for existing consumers; it configures the same NixOS module. |

Every entry point configures the NixOS module with the receiving evaluation's `lib`, and plain Nix imports evaluate no development inputs. The [API reference](docs/api.md#compatibility-adapter) explains how to migrate from `lib.mkModule` to `nixosModules.default`.

## Requirements

- All nodes in a collection use one nixpkgs revision and are evaluated within one Nix computation. Each node can have its own module evaluation, and source modules can come from separate repositories.
- Each entry in the collection exposes its evaluated configuration as `.config`, as `nixpkgs.lib.nixosSystem` results do. Nodes built by other host and guest helpers qualify; the [host and guest tests](tests/suites/host-guest.nix) include a guest created through NixOS's `containers` option.

The checks run against NixOS 26.05 and the [shared project policy](docs/development.md#ci-and-policy)'s stable and unstable nixpkgs revisions, on `x86_64-linux` and `aarch64-linux`.

## Install

Add the flake input and let it follow the consumer's nixpkgs:

```nix
inputs.crossConfig.url = "github:petohorvath/nixos-cross-config";
inputs.crossConfig.inputs.nixpkgs.follows = "nixpkgs";
```

Import `crossConfig.nixosModules.default` on every participating node and set its three required options. Without flakes, import `nixos/module.nix` from a checkout instead.

| Option                           | Value                                                                                                                          |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `crossConfig.name`               | This node's identity in the collection, such as `"application"`.                                                               |
| `crossConfig.nodeConfigurations` | The lazy attribute set of all nodes in the collection.                                                                         |
| `crossConfig.optionPaths`        | The list of allowed option paths, each a nonempty list of literal attribute names. An explicit `[ ]` permits no contributions. |

Every node must use the same collection and allowed option paths, so define those two in a settings module that all nodes import, and set `crossConfig.name` on each node. Path lists from several modules merge, and duplicate paths deliver contributions once. Importing the module enables both sending and receiving; there is no separate enable option.

## Usage

The following flake defines two NixOS container configurations, `application` and `proxy`. The application contributes the proxy settings for its virtual host, and the proxy defines a server alias for the same host locally:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.crossConfig.url = "github:petohorvath/nixos-cross-config";
  inputs.crossConfig.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    { nixpkgs, crossConfig, ... }:
    let
      modules = {
        application.crossConfig.contributions.proxy.services.nginx.virtualHosts."app.example" = {
          locations."/".proxyPass = "http://192.0.2.10:8080";
        };
        proxy.services.nginx = {
          enable = true;
          virtualHosts."app.example".serverAliases = [ "www.app.example" ];
        };
      };
      sharedSettings = {
        imports = [ crossConfig.nixosModules.default ];
        crossConfig = {
          nodeConfigurations = nodes;
          optionPaths = [
            [
              "services"
              "nginx"
              "virtualHosts"
            ]
          ];
        };
      };
      nodes = builtins.mapAttrs (
        name: module:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            sharedSettings
            {
              crossConfig.name = name;
              boot.isContainer = true;
              networking.hostName = "${name}-container";
              system.stateVersion = "26.05";
            }
            module
          ];
        }
      ) modules;
    in
    {
      nixosConfigurations = nodes;
    };
}
```

`sharedSettings` passes the `nodes` collection to every node lazily, and each node's identity comes from its attribute name rather than its hostname. The container settings keep the example independent of host hardware.

Save the flake as `flake.nix` in a new directory, and run `git add flake.nix` if the directory is in a Git repository. With the `nix-command` and `flakes` features enabled, evaluate the proxy's virtual host:

```bash
nix eval --json .#nixosConfigurations.proxy.config.services.nginx.virtualHosts \
  --apply 'hosts: { inherit (hosts."app.example") serverAliases; proxyPass = hosts."app.example".locations."/".proxyPass; }'
```

The result merges the application's contribution with the proxy's local definition:

```text
{"proxyPass":"http://192.0.2.10:8080","serverAliases":["www.app.example"]}
```

Nix creates `flake.lock` on the first evaluation. The backend address is illustrative; evaluation neither starts an application nor deploys either node. The same setup is in [examples/minimal.nix](examples/minimal.nix), which the test suite evaluates.

## Contributions

A sender defines contributions with ordinary nested assignments, starting with the receiver's identity and continuing with an allowed option path:

```nix
crossConfig.contributions.proxy.services.nginx.virtualHosts."app.example" = {
  locations."/".proxyPass = lib.mkDefault "http://192.0.2.10:8080";
};
```

Read the merged result from the receiver's configuration, such as `nodes.proxy.config`; the evaluated value of `crossConfig.contributions` is internal. A priority at or below the allowed option path applies on the receiver, as `lib.mkDefault` does here, so the proxy can still override the backend.

Some invalid contributions, such as one to a missing receiving option, fail only NixOS assertions. Reading a contributed value alone does not check them, so evaluate `config.system.build.toplevel` or `config.assertions` to validate a configuration.

The [API reference](docs/api.md) covers priorities, list ordering, conditions, sender values inside receiving submodules, self and reciprocal contributions, and validation errors.

## Share settings with flake-parts

Flake-parts consumers can import `crossConfig.flakeModules.default` and set `crossConfig.optionPaths` once at flake scope. The node collection defaults to the flake's `nixosConfigurations`; set `crossConfig.nodeConfigurations` at flake scope to select a subset or include guests. The module provides `config.flake.nixosModules.crossConfig`, which each node imports explicitly alongside its own `crossConfig.name`.

The configured module supplies the shared settings with `lib.mkDefault`, so extend path lists at flake scope: an ordinary node-level list replaces the shared list instead of adding to it. The [flake-parts guide](docs/flake-parts.md) shows default and explicit collections, and [examples/flake-parts.nix](examples/flake-parts.nix) is the evaluated example.

## Limitations

- No release is tagged yet. The [changelog](CHANGELOG.md) lists the unreleased breaking changes and their migration steps.
- Allowed option paths, node identities, and the receiver's imports and option declarations cannot depend on received values. Register paths unconditionally and put service-dependent conditions on the contributions.
- Allowed option paths cannot start with `crossConfig` or `_module`. These names remain valid deeper in a path.
- Node construction, discovery, and deployment remain the caller's responsibility.

## Contributing

Pull requests are welcome, and issues are tracked in [GitHub Issues](https://github.com/petohorvath/nixos-cross-config/issues). [CONTRIBUTING.md](CONTRIBUTING.md) describes the workflow, public contract, and release rules, and the [development instructions](docs/development.md) cover the development shell, formatter, and checks.

## License

Licensed under [MIT](LICENSE).
