{
  crossConfig,
  stable,
  unstable,
}:
let
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
  forSystems = stable.lib.genAttrs systems;
  collections = { inherit stable unstable; };
  testResults = forSystems (
    system:
    builtins.mapAttrs (
      _: nixpkgs:
      import ../tests {
        inherit crossConfig nixpkgs system;
      }
    ) collections
  );
  project = forSystems (
    system:
    let
      pkgs = stable.legacyPackages.${system};
      formatter = pkgs.callPackage ./formatter.nix { };
      checks =
        builtins.mapAttrs (
          _: nixpkgs:
          pkgs.callPackage ../tests/check-evaluation.nix {
            inherit nixpkgs system;
          }
        ) collections
        // stable.lib.mapAttrs' (
          channel: nixpkgs:
          stable.lib.nameValuePair "${channel}-value-cycle" (
            pkgs.callPackage ../tests/check-value-cycle.nix {
              inherit nixpkgs system;
            }
          )
        ) collections
        // stable.lib.mapAttrs' (
          channel: nixpkgs:
          stable.lib.nameValuePair "${channel}-diagnostics" (
            pkgs.callPackage ../tests/check-diagnostics.nix {
              inherit nixpkgs system;
            }
          )
        ) collections
        // {
          formatting = mkCheck {
            name = "cross-config-formatting";
            packages = [ formatter ];
            script = "cross-config-fmt --ci";
          };
          lint = mkCheck {
            name = "cross-config-lint";
            packages = [
              pkgs.statix
              pkgs.deadnix
              pkgs.ruff
              pkgs.actionlint
            ];
            script = ''
              statix check .
              deadnix --fail .
              ruff check dev/benchmarks
              actionlint .github/workflows/*.yml
            '';
          };
        };
      mkCheck =
        {
          name,
          packages,
          script,
        }:
        pkgs.runCommand name { nativeBuildInputs = packages; } ''
          cp -R ${sourceDir} source
          chmod -R u+w source
          cd source
          ${script}
          touch "$out"
        '';
      sourceDir = pkgs.lib.cleanSource ../.;
    in
    {
      inherit checks formatter;
      shell = pkgs.mkShellNoCC {
        packages = [
          pkgs.nix
          pkgs.nil
          pkgs.nixfmt
          pkgs.statix
          pkgs.deadnix
          pkgs.git
          pkgs.shfmt
          pkgs.prettier
          pkgs.ruff
          pkgs.actionlint
          pkgs.python3
          pkgs.time
          formatter
        ];
      };
    }
  );
in
{
  devShells = forSystems (system: {
    default = project.${system}.shell;
  });
  formatter = forSystems (system: project.${system}.formatter);
  checks = forSystems (system: project.${system}.checks);

  tests = testResults;
  failures = forSystems (
    system:
    builtins.mapAttrs (
      _: nixpkgs:
      let
        mkNodes = import ../tests/mk-nodes.nix {
          inherit crossConfig nixpkgs system;
        };
      in
      import ../tests/failures.nix { inherit mkNodes; }
      // {
        valueCycle = import ../tests/value-cycle.nix { inherit mkNodes; };
        taggedValueCycle = import ../tests/tagged-value-cycle.nix { inherit mkNodes; };
      }
    ) collections
  );

  nixosConfigurations = import ../examples/minimal.nix {
    inherit crossConfig;
    nixpkgs = stable;
  };
}
