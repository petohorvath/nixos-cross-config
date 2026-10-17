{ pkgs }:
{
  lint = pkgs.runCommand "cross-config-lint" { nativeBuildInputs = [ pkgs.statix ]; } ''
    cd ${../.}
    statix check .
    touch "$out"
  '';
}
