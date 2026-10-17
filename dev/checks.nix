{ pkgs }:
{
  lint =
    pkgs.runCommand "cross-config-lint"
      {
        src = ../.;
        nativeBuildInputs = [ pkgs.statix ];
      }
      ''
        cd "$src"
        statix check .
        touch "$out"
      '';
}
