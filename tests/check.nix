{
  lib,
  runCommand,
  testRunner,
}:
runCommand "cross-config-tests" { nativeBuildInputs = [ testRunner ]; } ''
  bash ${./helpers/check-runner.sh} ${./fixtures/runner.nix}
  cd ${lib.cleanSource ../.}
  cross-config-test
  touch "$out"
''
