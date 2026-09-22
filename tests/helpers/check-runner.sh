#!/usr/bin/env bash
set -euo pipefail

fixtureDir=$(mktemp -d)
trap 'rm -rf "$fixtureDir"' EXIT
mkdir "$fixtureDir/dev"
cp "$1" "$fixtureDir/dev/tests.nix"
chmod u+w "$fixtureDir/dev/tests.nix"
cd "$fixtureDir"

expect() {
  local expectedStatus=$1 expectedOutput=$2 status=0
  shift 2
  cross-config-test "$@" >result.log 2>&1 || status=$?
  if [[ $status != "$expectedStatus" || $(<result.log) != *"$expectedOutput"* ]]; then
    printf 'Runner regression: arguments %s, expected status %s and output %s, got status %s\n' \
      "$*" "$expectedStatus" "$expectedOutput" "$status" >&2
    cat result.log >&2
    exit 1
  fi
}

expect 0 'All selected tests passed (2)' passing
expect 0 'All selected tests passed (1)' passing.testError
expect 0 'discovery.testLazy' --list discovery
expect 1 'mismatches.testValue' mismatches.testValue
expect 1 'Expected error type' mismatches.testErrorType
expect 1 'Expected error msg pattern' mismatches.testErrorMessage
expect 1 'Expected error, but no error was caught' mismatches.testMissingError
expect 1 'expected error to include' mismatches.testDiagnostic
expect 1 'Test run failed' # The full run must also reject unmet expectations.
expect 2 'No tests match' absent

cat >dev/tests.nix <<'EOF'
_: {
  testInvalidTrace = {
    expr = throw "Expected rejection.";
    expectedError = { type = "ThrownError"; trace = "not a list"; };
  };
}
EOF
expect 1 'expectedError.trace must be a list of strings'

cat >dev/tests.nix <<'EOF'
_: { }
EOF
expect 2 'No tests match'
expect 2 'No tests match' --list
