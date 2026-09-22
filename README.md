# nixos-cross-config

Define NixOS options for one node from another node's modules. For example, an application node can define its nginx virtual host on a proxy node. NixOS merges these definitions with the proxy's local settings.

## Quickstart

This example evaluates two NixOS container configurations: `application` and `proxy`. Each named configuration is a **node**. The application is the **sender**, and the proxy is the **receiver**. The virtual host definition that the application supplies is a **contribution**.

With Nix and the `nix-command` and `flakes` features enabled, save the following as `flake.nix` in a new directory:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.crossConfig.url = "github:petohorvath/nixos-cross-config";
  inputs.crossConfig.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, crossConfig, ... }:
    let
      system = "x86_64-linux";

      # Both nodes import the same collection settings.
      sharedSettings = {
        imports = [ crossConfig.nixosModules.default ];
        crossConfig = {
          nodeCollection = nodes;
          optionPaths = [ [ "services" "nginx" "virtualHosts" ] ];
        };
      };

      modules = {
        application = {
          crossConfig.nodes.proxy.services.nginx.virtualHosts."app.example" = {
            locations."/".proxyPass = "http://192.0.2.10:8080";
          };
        };

        proxy = {
          services.nginx = {
            enable = true;
            virtualHosts."app.example".serverAliases = [ "www.app.example" ];
          };
        };
      };

      nodes = builtins.mapAttrs (name: module:
        nixpkgs.lib.nixosSystem {
          inherit system;
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

The `nodes` attribute set contains both evaluated configurations. The shared module supplies that collection lazily through `crossConfig.nodeCollection`. Each node sets `crossConfig.name` to its collection identity: `application` or `proxy`, independently of its hostname.

The container settings keep this example independent of host hardware. The backend address is illustrative; the example evaluates configuration without starting an application or deploying either node.

If the directory is in a Git repository, run `git add flake.nix` before evaluation. Run the following command from the directory containing `flake.nix`; Nix creates `flake.lock` to pin the inputs:

```bash
nix eval --json .#nixosConfigurations.proxy.config.services.nginx.virtualHosts \
  --apply 'hosts: hosts."app.example".locations."/".proxyPass'
# "http://192.0.2.10:8080"
```

The result is part of the proxy's normal NixOS configuration. Its virtual host also keeps the locally defined `serverAliases = [ "www.app.example" ];`.

The repository's [minimal example](examples/minimal.nix) uses the same setup and runs in the test suite. See [focused checks](docs/development.md#focused-checks) to run its `example` suite from a checkout.

## API

### `nixosModules.default`

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

Import this module on every participating node. All three settings are required:

| Option                       | Value                                                                                                                                  |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `crossConfig.name`           | This node's key in the collection, such as `"application"`. It can differ from `networking.hostName`.                                  |
| `crossConfig.nodeCollection` | The shared, lazy attribute set of nodes. Each entry exposes its evaluated configuration as `.config`.                                  |
| `crossConfig.optionPaths`    | The shared list of allowed paths. Each path is a nonempty list of literal string segments. An explicit `[ ]` permits no contributions. |

Importing the module enables both sending and receiving. There is no separate enable option. The receiver's own modules must declare the options that receive contributions.

Share the collection and registrations through imported settings modules. Path lists merge with normal option priorities, and duplicate paths deliver contributions only once. Every participant must use the same collection and normalized path set. Register paths independently of receiving configuration and put service-dependent conditions on contributions. The roots `crossConfig` and `_module` are reserved; those names remain valid below an ordinary receiving root.

Existing consumers can continue calling `crossConfig.lib.mkModule { inherit name nodes optionPaths; }`. This compatibility adapter configures the same module. The [API reference](docs/api.md#compatibility-adapter) explains plain-import access and migration.

### `flakeModules.default`

Flake-parts consumers can import `crossConfig.flakeModules.default` and set `crossConfig.optionPaths` once at flake scope. The adapter provides `config.flake.nixosModules.crossConfig`; each participating node imports that configured NixOS module and sets its own `crossConfig.name`. The node collection defaults lazily to the consumer's `flake.nixosConfigurations`, or `crossConfig.nodeCollection` can select an explicit collection containing subsets or guests.

The caller still constructs every node and imports the configured module explicitly. Shared settings enter NixOS as `mkDefault` definitions, so extend path lists at flake scope: an ordinary node-level list replaces the supplied default. See the [flake-parts guide](docs/flake-parts.md) and [evaluated example](examples/flake-parts.nix). Flake-parts remains optional for standalone consumers.

### `crossConfig.nodes`

In the sender's module, set `crossConfig.nodes.<receiver>.<option-path>`:

```nix
crossConfig.nodes.proxy.services.nginx.virtualHosts."app.example" = {
  locations."/".proxyPass = "http://192.0.2.10:8080";
};
```

Read the merged result from `nodes.<receiver>.config`, as the quickstart command does. `crossConfig.nodes` declares outgoing contributions; its evaluated representation is internal.

Contributions and local definitions use normal NixOS merging rules. A local definition has no extra priority. Use `lib.mkDefault`, `lib.mkForce`, and list ordering helpers where needed. The [API reference](docs/api.md) explains merging, conditions, validation, and evaluation limits.

## Use with existing configurations

Add the library input to the existing flake and import `nixosModules.default` on each participating node. Supply the existing collection through `crossConfig.nodeCollection`, compose `crossConfig.optionPaths` in shared settings modules, and set each node's `crossConfig.name` locally.

Keep each host's hardware configuration and existing `system.stateVersion`. The library accepts nodes built by existing host and guest helpers as long as each entry exposes `.config`. The [host and guest example in the tests](tests/host-guest.nix) shows how to include a guest created through NixOS's `containers` option.

## Support

All nodes in a collection must use one nixpkgs revision and be accessible within one Nix computation. Source modules can come from separate repositories, and each node can have its own module evaluation. Node construction and deployment remain the caller's responsibility.

Development supports `x86_64-linux` and `aarch64-linux`. The root lock selects NixOS 26.05 for ordinary checks. The selected `v0.3.0` policy workflow provides separate default checks and stable and unstable compatibility runs through native input overrides. Required coverage on both architectures depends on coordinated central records and verified merge gates. The project has no VM suite or tagged release yet. See [CI and policy](docs/development.md#ci-and-policy) for coverage and activation requirements.

## Documentation

- [API reference](docs/api.md): module settings, compatibility adapter, contributions, merging, conditions, and errors.
- [Development and checks](docs/development.md).
- [Domain glossary](CONTEXT.md).
- [Architectural decisions](docs/adr/).
- [Destination inspection design](docs/destination-inspection.md): how the implementation checks receiving options.

## Development

The root flake supplies the development shell, formatter, and checks through a partition in `dev/`, using one selected `nixpkgs` input. The checks cover the examples. Run `nix fmt --no-update-lock-file` and `nix flake check --no-update-lock-file` from the repository root. Inside the development shell, `cross-config-test` runs the same tests and accepts a suite or test name for focused runs. Native input overrides select another exact revision for the whole evaluation without changing the committed lock. [Development instructions](docs/development.md) cover prerequisites, exact-revision compatibility checks, focused checks, and CI.

## Contributing

Follow [CONTRIBUTING.md](CONTRIBUTING.md) for the shared policy, PR workflow, public contracts, and release rules. [CHANGELOG.md](CHANGELOG.md) records unreleased changes and migration notes. Original code is licensed under [MIT](LICENSE).
