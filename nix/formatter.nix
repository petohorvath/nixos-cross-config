{
  writeShellApplication,
  treefmt,
  nixfmt,
  shfmt,
  prettier,
  ruff,
}:
writeShellApplication {
  name = "cross-config-fmt";
  runtimeInputs = [
    treefmt
    nixfmt
    shfmt
    prettier
    ruff
  ];
  text = ''
    exec treefmt --tree-root . --walk filesystem --config-file ${../treefmt.toml} "$@"
  '';
}
