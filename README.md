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

      # Both nodes use the same allowed option paths.
      optionPaths = [ [ "services" "nginx" "virtualHosts" ] ];

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
            (crossConfig.lib.mkModule { inherit name nodes optionPaths; })
            {
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

The `nodes` attribute set contains both evaluated configurations. Nix's recursive `let` bindings let each call to `mkModule` refer to that same set. `name` identifies the node being configured: `application` or `proxy`.

The container settings keep this example independent of host hardware. The backend address is illustrative; the example evaluates configuration without starting an application or deploying either node.

If the directory is in a Git repository, run `git add flake.nix` before evaluation. Run the following command from the directory containing `flake.nix`; Nix creates `flake.lock` to pin the inputs:

```bash
nix eval --json .#nixosConfigurations.proxy.config.services.nginx.virtualHosts \
  --apply 'hosts: hosts."app.example".locations."/".proxyPass'
# "http://192.0.2.10:8080"
```

The result is part of the proxy's normal NixOS configuration. Its virtual host also keeps the locally defined `serverAliases = [ "www.app.example" ];`.

The repository's [minimal example](examples/minimal.nix) uses the same setup and runs in the test suite. From a checkout, the command above evaluates that example too.

## API

### `lib.mkModule`

```nix
crossConfig.lib.mkModule { inherit name nodes optionPaths; }
```

This function returns a NixOS module. Add it to `nixosSystem.modules` or a module's `imports` on every participating node. All three arguments are required:

| Argument      | Value                                                                                                                                     |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `name`        | This node's key in `nodes`, such as `"application"`. It can differ from `networking.hostName`.                                            |
| `nodes`       | The shared attribute set of nodes. Each entry exposes its evaluated configuration as `nodes.<name>.config`.                               |
| `optionPaths` | The shared list of allowed option paths. Each path is a list of literal attribute names, such as `[ "services" "nginx" "virtualHosts" ]`. |

Importing the module enables both sending and receiving. There is no separate enable option. The receiver's own modules must declare the options that receive contributions.

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

Add the library input to the existing flake. Choose the shared `optionPaths`, and include the module returned by `mkModule` in each participating node's module list. Supply the existing node collection as `nodes`.

Keep each host's hardware configuration and existing `system.stateVersion`. The library accepts nodes built by existing host and guest helpers as long as each entry exposes `.config`. The [host and guest example in the tests](tests/host-guest.nix) shows how to include a guest created through NixOS's `containers` option.

## Support

All nodes in a collection must use one nixpkgs revision and be accessible within one Nix computation. Source modules can come from separate repositories, and each node can have its own module evaluation. Node construction and deployment remain the caller's responsibility.

Development supports `x86_64-linux` and `aarch64-linux`. The root lock selects NixOS 26.05 for ordinary checks. The selected `v0.2.0` policy workflow provides separate default checks and stable and unstable compatibility runs through native input overrides. Required coverage on both architectures depends on coordinated central records and verified merge gates. The project has no VM suite or tagged release yet. See [CI and policy](docs/development.md#ci-and-policy) for coverage and activation requirements.

## Documentation

- [API reference](docs/api.md): arguments, option paths, contributions, merging, conditions, and errors.
- [Development and checks](docs/development.md).
- [Domain glossary](CONTEXT.md).
- [Architectural decisions](docs/adr/).
- [Destination inspection design](docs/destination-inspection.md): how the implementation checks receiving options.

## Development

The root flake supplies the development shell, formatter, package, example, and checks using one selected `nixpkgs` input. Run `nix fmt --no-update-lock-file` and `nix flake check --no-update-lock-file` from the repository root. Native input overrides select another exact revision for the whole evaluation without changing the committed lock. [Development instructions](docs/development.md) cover prerequisites, exact-revision compatibility checks, focused checks, and CI.

## Contributing

Follow [CONTRIBUTING.md](CONTRIBUTING.md) for the shared policy, PR workflow, public contracts, and release rules. [CHANGELOG.md](CHANGELOG.md) records unreleased changes and migration notes. Original code is licensed under [MIT](LICENSE).
