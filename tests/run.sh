# shellcheck shell=bash

usage() {
  cat <<'EOF'
Usage: cross-config-test [--list] [SUITE_OR_TEST]

Run all tests from the repository root, or select a suite or test by name.
Every selected test includes its value, error, and diagnostic expectations.
Use --list to list matching tests without evaluating their expressions.
EOF
}

listOnly=false
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  usage
  exit 0
fi
if [[ ${1:-} == --list ]]; then
  listOnly=true
  shift
fi
if [[ $# -gt 1 || ${1:-} == -* ]]; then
  usage >&2
  exit 2
fi
selection=${1:-}
suitePath="$PWD/dev/tests.nix"
if [[ ! -f $suitePath ]]; then
  echo 'Run cross-config-test from the repository root (dev/tests.nix is missing).' >&2
  exit 2
fi

testDir=$(mktemp -d)
cleanup() {
  # The temporary evaluation store contains read-only store directories.
  chmod -R u+w "$testDir"
  rm -rf "$testDir"
}
trap cleanup EXIT
arguments=(
  --arg nixpkgs "(import $inputsPath).nixpkgs"
  --arg flakeParts "(import $inputsPath).flakeParts"
  --argstr system "$system"
)
evaluation=(nix eval --extra-experimental-features nix-command --offline
  --read-only --store dummy:// --json --file "$suitePath" "${arguments[@]}")

"${evaluation[@]}" --apply \
  "load: import $manifestPath { lib = (import $inputsPath).nixpkgs.lib; tests = load { inherit (import $inputsPath) flakeParts nixpkgs; system = \"$system\"; }; }" \
  >"$testDir/manifest.json"
jq --arg selection "$selection" \
  '[.[] | select($selection == "" or .name == $selection or (.name | startswith($selection + ".")))]' \
  "$testDir/manifest.json" >"$testDir/selected.json"
total=$(jq length "$testDir/selected.json")
if [[ $total == 0 ]]; then
  printf 'No tests match %q. Use cross-config-test --list to see available tests.\n' "$selection" >&2
  exit 2
fi
if $listOnly; then
  jq -r '.[].name' "$testDir/selected.json"
  exit 0
fi

printf 'Running tests (%s selected)\n' "$total"
jq 'group_by(.batch)' "$testDir/selected.json" >"$testDir/batches.json"
batchCount=$(jq length "$testDir/batches.json")
failed=false
for ((batch = 0; batch < batchCount; batch++)); do
  jq --argjson batch "$batch" '.[$batch]' "$testDir/batches.json" >"$testDir/batch.json"
  mapfile -t attributes < <(jq -r '.[].name' "$testDir/batch.json")
  selectors=()
  for attribute in "${attributes[@]}"; do
    selectors+=(--attr "$attribute")
  done
  printf 'Checking %s\n' "${attributes[@]}"
  if ! nix-unit --quiet --eval-store "$testDir/eval-store" --gc-roots-dir "$testDir/gc-roots" \
    "$suitePath" "${arguments[@]}" "${selectors[@]}" >"$testDir/unit.log" 2>&1; then
    cat "$testDir/unit.log" >&2
    failed=true
    continue
  fi

  while IFS= read -r test; do
    name=$(jq -r .name <<<"$test")
    fragmentCount=$(jq '.trace | length' <<<"$test")
    passed=true
    if [[ $fragmentCount -gt 0 ]]; then
      if "${evaluation[@]}" --show-trace "$name.expr" >"$testDir/value.json" 2>"$testDir/error.log"; then
        printf 'FAIL %s: expected evaluation to fail\n' "$name" >&2
        cat "$testDir/value.json" >&2
        passed=false
      else
        missing=$(jq -n --argjson test "$test" --rawfile error "$testDir/error.log" \
          '[$test.trace[] | select(. as $fragment | $error | contains($fragment) | not)]')
        if [[ $missing != '[]' ]]; then
          printf 'FAIL %s: expected error to include %s\n' "$name" "$missing" >&2
          cat "$testDir/error.log" >&2
          passed=false
        fi
      fi
    fi
    if $passed; then
      printf 'PASS %s\n' "$name"
    else
      failed=true
    fi
  done < <(jq -c '.[]' "$testDir/batch.json")
done

if $failed; then
  echo 'Test run failed; see the named tests above.' >&2
  exit 1
fi
printf 'All selected tests passed (%s)\n' "$total"
