{
  formatter,
  inputs,
  pkgs,
}:
let
  sourceDir = pkgs.lib.cleanSource ../.;

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
in
pkgs.lib.attrsets.unionOfDisjoint (import ../tests { inherit inputs pkgs; }) {
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
      pkgs.actionlint
    ];
    script = ''
      statix check .
      deadnix --fail .
      actionlint .github/workflows/*.yml
    '';
  };
}
